class String

	def remove_tag(tag)
		tag = tag.strip
		if self.include? tag
			return self.gsub(tag, '').gsub(/,\s*,/, ',').gsub(/(\A\s*,\s*|\s*,\s*\z)/, '')
		end

		self
	end

	def add_tag(tag)
		new_string = self.strip
		if new_string.length == 0
			new_string = tag
		else
			new_string << ', ' << tag unless new_string.include? tag
		end

		new_string
	end

end