# fluent-plugin-fluent-package-update-notifier

[Fluentd](https://fluentd.org/) input plugin to notify with
update logging when newer `fluent-package` is available.

## Installation

### RubyGems

```
$ gem install fluent-plugin-fluent-package-update-notifier
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-fluent-package-update-notifier"
```

And then execute:

```
$ bundle
```

## Configuration

|parameter|type|description|default|
|---|---|---|---|
|lts|bool (optional)|Notify fluent-package updates which depends on channel (e.g. Monitor LTS by default)|`true`|
|notify_major_upgrade|bool (optional)|Notify whether major upgrade is available or not (e.g. from v5 to v6)|`true`|
|notify_level|enum (optional)|Specify notification log level when update is available (`info`, `warn`)|`info`|
|notify_interval|integer (optional)|Notify checking update intervals|`86400`|
|repository_sites|array (optional)|Package repository site|`["https://packages.treasuredata.com"]`|

## Example

If you want to collect update notification via log stream to specific file, let's configure it with @FLUENT_LOG label:

```
<source>
  @type fluent_package_update_notifier
</source>

<label @FLUENT_LOG>
  <match fluent.{warn,info}>
    @type file
    path notify-fluent-log
    <buffer []>
      flush_at_shutdown
    </buffer>
  </match>
</label>
```

When shutting down fluentd, `notify-fluent-log_0.log` or similar file (`notify-fluent-log_N.log`) will be saved.

```
2025-04-21T12:30:53+09:00       fluent.info     {"pid":134883,"ppid":134869,"worker":0,"message":"starting fluentd worker pid=134883 ppid=134869 worker=0"}
2025-04-21T12:30:53+09:00       fluent.info     {"message":"fluent-package v5.0.6 is available! See https://github.com/fluent/fluent-package-builder/releases/tag/v5.0.6 in details.\n"}
2025-04-21T12:30:53+09:00       fluent.info     {"worker":0,"message":"fluentd worker is now running worker=0"}
2025-04-21T12:31:00+09:00       fluent.info     {"worker":0,"message":"fluentd worker is now stopping worker=0"}
```

## Copyright

* Copyright(c) 2025- Kentaro Hayashi
* License
  * Apache License, Version 2.0
