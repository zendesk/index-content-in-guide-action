module ColoredLoggingFormatter
  COLORS = {
    black: 30,
    blue:  34,
    yellow: 33,
    cyan: 36,
    green: 32,
    magenta: 35,
    red: 31,
    white: 37
  }

  class << self
    def call(severity, datetime, progname, msg)
      color = case severity
      when "DEBUG" then :cyan
      when "INFO" then :white
      when "WARN" then :yellow
      when "ERROR" then :yellow
      end

      code = COLORS.fetch(color)

      [
        "\e[#{code}m",
        severity.ljust(5, " "),
        "[" + datetime.strftime("%k:%M") + "]",
        msg,
        "\033[0m",
        "\n",
      ].join("  ")
    end
  end
end
