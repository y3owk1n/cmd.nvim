# Changelog

## 1.0.0 (2025-12-14)


### Features

* add `notifier.nvim` adapter ([#24](https://github.com/y3owk1n/cmd.nvim/issues/24)) ([5401746](https://github.com/y3owk1n/cmd.nvim/commit/540174697858d244ae1794a37521c0c94e3098a0))
* add healthcheck ([#16](https://github.com/y3owk1n/cmd.nvim/issues/16)) ([7d8c189](https://github.com/y3owk1n/cmd.nvim/commit/7d8c189472e05d99a034e722d60dce54f6f2e1fa))
* **cmd:** init plugin from my config ([#1](https://github.com/y3owk1n/cmd.nvim/issues/1)) ([02dfceb](https://github.com/y3owk1n/cmd.nvim/commit/02dfceb15a0cffdfcbddaf020a707c7f551358b3))
* improvement to prevent frequent buffer appearance on `success` or `failed` commands ([#22](https://github.com/y3owk1n/cmd.nvim/issues/22)) ([e583318](https://github.com/y3owk1n/cmd.nvim/commit/e583318b2067d222cfa1b7591903fd5592878c14))


### Bug Fixes

* add the same progress spinner to terminal commands ([#11](https://github.com/y3owk1n/cmd.nvim/issues/11)) ([29d8186](https://github.com/y3owk1n/cmd.nvim/commit/29d8186b7b29004a83cbdc5d213e32e9bb734a93))
* **ci:** move docs to another workflow ([#10](https://github.com/y3owk1n/cmd.nvim/issues/10)) ([284b328](https://github.com/y3owk1n/cmd.nvim/commit/284b328e7bd8ba62da41381cde949886173db7fe))
* **completion:** attempt to make completion work with bash & zsh ([#20](https://github.com/y3owk1n/cmd.nvim/issues/20)) ([c4f90ae](https://github.com/y3owk1n/cmd.nvim/commit/c4f90aea38a3bd1bb2746756102dc2e04e30d957))
* **completion:** match `fish` not equal `fish` ([#7](https://github.com/y3owk1n/cmd.nvim/issues/7)) ([fb84741](https://github.com/y3owk1n/cmd.nvim/commit/fb84741f76ea2636d4d3cd533d591ff372925da1))
* **completion:** validate shell before trying to complete it ([#19](https://github.com/y3owk1n/cmd.nvim/issues/19)) ([4127856](https://github.com/y3owk1n/cmd.nvim/commit/41278560da2bf289aa03bf8e7ad455d6821bbd65))
* **docs:** remove `Cmd!!` from docs, use `CmdRerun` instead ([54793cc](https://github.com/y3owk1n/cmd.nvim/commit/54793cc64dac30d02807621b0ef6c095490b7692))
* **doc:** update doc annotation and avoid label duplication ([#21](https://github.com/y3owk1n/cmd.nvim/issues/21)) ([b27d2a5](https://github.com/y3owk1n/cmd.nvim/commit/b27d2a521a05fc4e12ea521cc23bb7fb3ef9d97f))
* ensure check shell is not nil ([#23](https://github.com/y3owk1n/cmd.nvim/issues/23)) ([92d6215](https://github.com/y3owk1n/cmd.nvim/commit/92d62159bc71c8d55b00b37e0718ae36109ed1d5))
* **history:** use floats for history and make it configurable ([#5](https://github.com/y3owk1n/cmd.nvim/issues/5)) ([4e18ac0](https://github.com/y3owk1n/cmd.nvim/commit/4e18ac0909626c9b377ac9b5c89b17f482120271))
* refactor code for better maintainability and clarity ([#15](https://github.com/y3owk1n/cmd.nvim/issues/15)) ([0b032d3](https://github.com/y3owk1n/cmd.nvim/commit/0b032d3238616b453cb4a2048e42d7fbda282939))
* refactor function style to my liking ([#17](https://github.com/y3owk1n/cmd.nvim/issues/17)) ([4b1d954](https://github.com/y3owk1n/cmd.nvim/commit/4b1d9546614adb3ba86bc46e5aed7a0bfb80fc2e))
* remove debug notify ([#18](https://github.com/y3owk1n/cmd.nvim/issues/18)) ([b70f7f8](https://github.com/y3owk1n/cmd.nvim/commit/b70f7f8898757e5e8889f41918ee6e5dc25d91a8))
* rename `async_notifier` to `progress_notifier` and it's types ([#12](https://github.com/y3owk1n/cmd.nvim/issues/12)) ([14653eb](https://github.com/y3owk1n/cmd.nvim/commit/14653eb80db3ec566c0af95502f4373de1a7482b))
* **setup:** ensure only single setup to avoid inconsistency ([#6](https://github.com/y3owk1n/cmd.nvim/issues/6)) ([cf24aeb](https://github.com/y3owk1n/cmd.nvim/commit/cf24aeb190f82b7221b79f295bbf84e2da89d760))
