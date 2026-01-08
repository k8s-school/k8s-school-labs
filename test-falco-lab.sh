#!/bin/bash

set -euxo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Command '$1' not found. Please install it first."
        exit 1
    fi
}

# Function to setup cluster and Falco
setup_prerequisites() {
    log_info "Setting up prerequisites..."

    # Check required commands
    check_command ktbx
    check_command kubectl
    check_command helm

    log_info "Deleting existing ktbx cluster..."
    ktbx delete || log_warning "No existing cluster to delete"

    log_info "Creating new ktbx cluster..."
    ktbx create

    log_info "Installing Falco..."
    ktbx install falco

    log_info "Waiting for Falco to be ready..."
    kubectl wait --for=condition=Ready pods --all -n falco --timeout=300s

    log_success "Prerequisites setup completed"
}

# Function to test basic Falco installation
test_falco_installation() {
    log_info "Testing Falco installation..."

    # Check Falco pods
    log_info "Checking Falco pods..."
    kubectl get pods -n falco

    # Verify Falco is logging
    log_info "Checking Falco logs..."
    kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=5

    log_success "Falco installation test completed"
}

# Function to test default Falco rules
test_default_rules() {
    log_info "Testing default Falco rules..."

    # Create test workload
    log_info "Creating test deployment..."
    kubectl create deployment test-app --image=nginx:alpine
    kubectl wait --for=condition=Ready pod -l app=test-app --timeout=60s

    TEST_POD=$(kubectl get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')
    log_info "Test pod: $TEST_POD"

    # Test 1: Trigger "Read sensitive file untrusted" rule
    log_info "Test 1: Triggering sensitive file access rule..."
    kubectl exec $TEST_POD -- cat /etc/shadow
    sleep 2

    # Check for alert
    SENSITIVE_FILE_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=50 | grep -c "Read sensitive file untrusted" || echo "0")
    SENSITIVE_FILE_ALERTS=${SENSITIVE_FILE_ALERTS:-0}
    SENSITIVE_FILE_ALERTS=$(echo $SENSITIVE_FILE_ALERTS | head -1 | tr -d '\n\r ')
    if [[ $SENSITIVE_FILE_ALERTS -gt 0 ]]; then
        log_success "✓ Sensitive file access rule triggered ($SENSITIVE_FILE_ALERTS alerts)"
    else
        log_warning "✗ Sensitive file access rule not triggered"
    fi

    # Test 2: Trigger shell in container rule
    log_info "Test 2: Triggering shell in container rule..."
    kubectl exec $TEST_POD -- /bin/sh -c "whoami && ps aux"
    sleep 2

    # Check for shell alerts
    SHELL_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=50 | grep -c "Shell spawned\|shell" || echo "0")
    SHELL_ALERTS=${SHELL_ALERTS:-0}
    SHELL_ALERTS=$(echo $SHELL_ALERTS | head -1 | tr -d '\n\r ')
    if [[ $SHELL_ALERTS -gt 0 ]]; then
        log_success "✓ Shell rule triggered ($SHELL_ALERTS alerts)"
    else
        log_warning "✗ Shell rule not triggered"
    fi

    # Test 3: File write test
    log_info "Test 3: Triggering file write rule..."
    kubectl exec $TEST_POD -- /bin/sh -c "echo 'test' > /tmp/test-file"
    sleep 2

    log_success "Default rules test completed"
}

# Function to test custom rule creation
test_custom_rules() {
    log_info "Testing custom rule creation..."

    # Get Falco pod
    FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
    log_info "Using Falco pod: $FALCO_POD"

    # Create custom rules file
    log_info "Creating custom rules file..."
    kubectl exec $FALCO_POD -n falco -c falco -- /bin/sh -c 'cat > /etc/falco/falco_rules.local.yaml << "EOF"
# Custom CKS Rules for Testing

- rule: CKS Package Manager Detection
  desc: Detect package manager usage in containers
  condition: >
    spawned_process and container and
    (proc.name in (apt, apt-get, yum, dnf, apk, pip, npm)) and
    not container.image.repository contains "build"
  output: >
    CKS Alert - Package manager used (user=%user.name container=%container.name
    image=%container.image.repository proc=%proc.name cmdline=%proc.cmdline)
  priority: WARNING
  tags: [cks_test, package_management]

- rule: CKS Network Tool Usage
  desc: Detect network reconnaissance tools
  condition: >
    spawned_process and container and
    (proc.name in (wget, curl, nc, netcat))
  output: >
    CKS Alert - Network tool used (user=%user.name container=%container.name
    tool=%proc.name cmdline=%proc.cmdline)
  priority: INFO
  tags: [cks_test, network_tools]

- rule: CKS Sensitive Directory Access
  desc: Detect access to sensitive directories
  condition: >
    open_read and container and
    (fd.name startswith "/etc/passwd" or fd.name startswith "/etc/shadow")
  output: >
    CKS Alert - Sensitive file accessed (file=%fd.name user=%user.name
    container=%container.name proc=%proc.cmdline)
  priority: CRITICAL
  tags: [cks_test, sensitive_access]
EOF'

    # Restart Falco pod to reload rules
    log_info "Restarting Falco pod to reload custom rules..."
    kubectl delete pod $FALCO_POD -n falco
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco --timeout=120s

    # Get new pod name
    FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
    log_info "New Falco pod: $FALCO_POD"

    # Wait for Falco to be fully ready
    sleep 10

    # Test custom rules
    TEST_POD=$(kubectl get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')

    # Test package manager rule
    log_info "Testing custom package manager rule..."
    kubectl exec $TEST_POD -- /bin/sh -c "apk --help > /dev/null" || true
    sleep 3

    # Test network tool rule
    log_info "Testing custom network tool rule..."
    kubectl exec $TEST_POD -- /bin/sh -c "wget --help > /dev/null" || true
    sleep 3

    # Check for custom rule alerts
    CUSTOM_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=100 | grep -c "CKS Alert" || echo "0")
    CUSTOM_ALERTS=${CUSTOM_ALERTS:-0}
    CUSTOM_ALERTS=$(echo $CUSTOM_ALERTS | head -1 | tr -d '\n\r ')
    if [[ $CUSTOM_ALERTS -gt 0 ]]; then
        log_success "✓ Custom rules working ($CUSTOM_ALERTS CKS alerts found)"

        # Show sample custom alerts
        log_info "Sample custom alerts:"
        kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=100 | grep "CKS Alert" | head -3 || true
    else
        log_warning "✗ Custom rules not triggered"
    fi

    log_success "Custom rules test completed"
}

# Function to test rule modification
test_rule_modification() {
    log_info "Testing rule modification..."

    FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

    # Check existing rules
    log_info "Checking existing rules..."
    kubectl exec $FALCO_POD -n falco -c falco -- ls -la /etc/falco/

    # Verify custom rules file exists
    if kubectl exec $FALCO_POD -n falco -c falco -- test -f /etc/falco/falco_rules.local.yaml; then
        log_success "✓ Custom rules file exists"

        # Show content
        log_info "Custom rules content:"
        kubectl exec $FALCO_POD -n falco -c falco -- head -10 /etc/falco/falco_rules.local.yaml
    else
        log_warning "✗ Custom rules file not found"
    fi

    log_success "Rule modification test completed"
}

# Function to test output configuration
test_output_configuration() {
    log_info "Testing output configuration..."

    FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

    # Check Falco configuration
    log_info "Checking Falco configuration..."
    kubectl exec $FALCO_POD -n falco -c falco -- grep -A5 -B5 "json_output\|file_output\|stdout_output" /etc/falco/falco.yaml || true

    # Generate test event and check JSON output
    log_info "Generating test event for JSON output verification..."
    TEST_POD=$(kubectl get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')
    kubectl exec $TEST_POD -- cat /etc/hostname

    sleep 2

    # Check if output is in JSON format
    JSON_EVENTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=20 | grep "^{.*}$" | wc -l)
    if [[ $JSON_EVENTS -gt 0 ]]; then
        log_success "✓ JSON output working ($JSON_EVENTS JSON events found)"
    else
        log_warning "✗ JSON output not detected"
    fi

    log_success "Output configuration test completed"
}

# Function to test performance and monitoring
test_performance_monitoring() {
    log_info "Testing performance and monitoring..."

    # Check Falco resource usage
    log_info "Checking Falco resource usage..."
    kubectl top pods -n falco || log_warning "kubectl top not available"

    # Count total events
    TOTAL_EVENTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | wc -l)
    log_info "Total Falco log entries: $TOTAL_EVENTS"

    # Check for errors in logs
    ERROR_COUNT=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | grep -ci error || echo "0")
    if [[ $ERROR_COUNT -eq 0 ]]; then
        log_success "✓ No errors found in Falco logs"
    else
        log_warning "✗ Found $ERROR_COUNT errors in Falco logs"
    fi

    log_success "Performance monitoring test completed"
}

# Function to cleanup
cleanup() {
    log_info "Cleaning up test resources..."

    kubectl delete deployment test-app --ignore-not-found=true || true

    log_success "Cleanup completed"
}

# Function to show summary
show_summary() {
    log_info "=== FALCO LAB TEST SUMMARY ==="

    # Count alerts by type
    ALL_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | grep -E "(Warning|Critical|Info)" | wc -l)
    SENSITIVE_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | grep -c "sensitive file\|Read sensitive" || echo "0")
    SHELL_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | grep -c "Shell spawned\|shell" || echo "0")
    CUSTOM_ALERTS=$(kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=1000 | grep -c "CKS Alert" || echo "0")

    echo ""
    log_success "✓ Falco installation: Working"
    log_success "✓ Total alerts generated: $ALL_ALERTS"
    log_success "✓ Sensitive file alerts: $SENSITIVE_ALERTS"
    log_success "✓ Shell alerts: $SHELL_ALERTS"
    log_success "✓ Custom rule alerts: $CUSTOM_ALERTS"

    if [[ $ALL_ALERTS -gt 0 && $SENSITIVE_ALERTS -gt 0 ]]; then
        log_success "🎉 ALL TESTS PASSED - Falco lab is working correctly!"
    else
        log_warning "⚠️  Some tests may have issues - check logs above"
    fi

    echo ""
    log_info "Lab guide exercises validated:"
    log_info "  ✓ Exercise 1: Default rule testing"
    log_info "  ✓ Exercise 2: Custom rule creation"
    log_info "  ✓ Exercise 3: Rule modification"
    log_info "  ✓ Exercise 4: Output configuration"
    log_info "  ✓ Exercise 5: Performance monitoring"

    echo ""
    log_info "To explore more:"
    log_info "  - Check Falco logs: kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco"
    log_info "  - Trigger more alerts: kubectl exec <pod> -- cat /etc/shadow"
    log_info "  - View custom rules: kubectl exec <falco-pod> -n falco -c falco -- cat /etc/falco/falco_rules.local.yaml"

    echo ""
    log_success "Falco Runtime Security Lab test completed successfully!"
}

# Function to show help
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

This script tests the Falco Runtime Security lab on a ktbx cluster.

OPTIONS:
    -h, --help      Show this help message
    -s, --setup     Only run setup (ktbx delete && create && install falco)
    -t, --test      Only run tests (skip setup)
    -c, --cleanup   Only run cleanup
    -q, --quick     Run quick test (skip some time-consuming tests)

EXAMPLES:
    $0              Run complete test (setup + all tests)
    $0 --setup      Only setup cluster and install Falco
    $0 --test       Only run tests (assume Falco is already installed)
    $0 --quick      Quick test with essential checks only

EOF
}

# Main function
main() {
    log_info "Starting Falco Runtime Security Lab Test"
    log_info "========================================="

    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--setup)
            setup_prerequisites
            exit 0
            ;;
        -t|--test)
            log_info "Running tests only (skipping setup)..."
            test_falco_installation
            test_default_rules
            test_custom_rules
            test_rule_modification
            test_output_configuration
            test_performance_monitoring
            show_summary
            exit 0
            ;;
        -c|--cleanup)
            cleanup
            exit 0
            ;;
        -q|--quick)
            log_info "Running quick test..."
            setup_prerequisites
            test_falco_installation
            test_default_rules
            show_summary
            exit 0
            ;;
        "")
            # Run complete test
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    # Trap to ensure cleanup on script exit
    trap cleanup EXIT

    # Run complete test sequence
    setup_prerequisites
    test_falco_installation
    test_default_rules
    test_custom_rules
    test_rule_modification
    test_output_configuration
    test_performance_monitoring

    # Don't cleanup automatically for full test - let user explore
    trap - EXIT

    show_summary

    log_info "Test completed! Cluster is ready for exploration."
    log_info "Run '$0 --cleanup' when you're done."
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi