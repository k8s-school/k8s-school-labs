# K8s-school Labs

Copyright (c) 2025 Fabrice Jammes

This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
See [LICENSE](LICENSE) file for full license terms.

## Install

## Theme management

```shell
cd themes
rmdir hugo-theme-learn
git clone https://github.com/k8s-school/hugo-theme-learn.git
cd hugo-theme-learn
git checkout k8s-school

# Update master to upstream
git remote add upstream https://github.com/matcornic/hugo-theme-learn.git 
git checkout master
git pull
# Then rebase branch k8s-school on master
```
