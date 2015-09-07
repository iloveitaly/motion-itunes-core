module AppSetup
  def setup
    self.setup_logging
    self.setup_error_reporting
  end

  def setup_logging
    file_logger = DDFileLogger.new
    file_logger.rollingFrequency = 60 * 60 * 24
    file_logger.logFileManager.maximumNumberOfLogFiles = 1

    # the logger causes macbacon to hang
    $log = Motion::Log
    $log.addLogger file_logger

    if BubbleWrap::App.test?
      $log.level = :off
      # $log.async = true
    else
      tty_logger = DDTTYLogger.sharedInstance
      # DDASLLogger.sharedInstance
      $log.level = :info
      # $log.addLogger DDASLLogger.sharedInstance
      $log.addLogger tty_logger
      $log.flush
    end

    $log.info "== Log Init =="
    $log.info "App Version: %s (%s)" % [
      NSBundle.mainBundle.objectForInfoDictionaryKey("CFBundleShortVersionString"),
      build_version
    ]
  end

  def setup_error_reporting(errbit_host)
    # always send crash reports to errbit
    NSUserDefaults.standardUserDefaults.setBool true, forKey: "AlwaysSendCrashReports"

    # write out test notice to ensure that error reporting is always working
    if BubbleWrap::App.development?
      # EBNotifier.writeTestNotice
    end

    EBNotifier.startNotifierWithAPIKey self.constants::ERRBIT_KEY,
                          serverAddress: errbit_host,
                        environmentName: (App.release?) ? "Development" : "Production",
                                 useSSL: false,
                               delegate: self
  end

  def build_version
    NSBundle.mainBundle.objectForInfoDictionaryKey("CFBundleVersion")
  end

  def error(msg, params = {})

  end
end
