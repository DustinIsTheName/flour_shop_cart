class Colorize

	def self.colorize(text, color_code)
	  "#{color_code}#{text}\e[0m"
	end

	def self.red(text)
	 self.colorize(text, "\e[31m")
	end
	def self.green(text)
	 self.colorize(text, "\e[32m")
	end
	def self.black(text)
		self.colorize(text, "\e[30m\e[47m")
	end
	def self.cyan(text)
		self.colorize(text, "\e[36m\e[1m")
	end
	def self.magenta(text)
		self.colorize(text, "\e[35m\e[1m")
	end
	def self.blue(text)
		self.colorize(text, "\e[38;5;27m")
	end
	def self.yellow(text)
		self.colorize(text, "\e[1;33m")
	end
	def self.bright(text)
		self.colorize(text, "\e[1;37m")
	end
	def self.orange(text)
		self.colorize(text, "\e[38;5;208m")
	end
	def self.purple(text)
		self.colorize(text, "\e[38;5;91m")
	end

end