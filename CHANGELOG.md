# 0.2.4 - 2026-10-19

* Fix checking the x64 msi for updates on ARM64 Windows (#26)
* Fix update check failing with TypeError on the standard channel (#27)
* Fix update check never finding deb packages on Debian and Ubuntu (#28)
* Fix update check never finding rpm packages on Red Hat compatible platforms and Amazon Linux (#29)
* Stop downloading whole packages when checking for updates (#30)

# 0.2.3 - 2025-08-28

* Remove unnecessary error log (#10)
* Relax log level (#11)

# 0.2.2 - 2025-08-27

* in_fluent_package_update_notifier: support multi worker (#8)

# 0.2.1 - 2025-08-22

* Relax log level (#6)
* Use :cmd backend for Windows platform (#4)
* gemspec: move development dependencies to Gemfile (#3)

# 0.2.0 - 2025-07-14

* Make robust for future distribution release

# 0.1.0 - 2025-04-22

* Initial release
