class CreateScript

	def self.activate
		file = ApplicationController.new.render_to_string(:template => "home/script_file.js", :layout => false)
		asset = ShopifyAPI::Asset.new
		asset.key = "assets/thank_you_page_script.js"
		asset.value = file

		if asset.save
		  if ShopifyAPI::ScriptTag.first
		    ShopifyAPI::ScriptTag.first.destroy
		  end

		  new_script_tag = ShopifyAPI::ScriptTag.new
		  new_script_tag.event = 'onload'
		  new_script_tag.src = asset.public_url
		  if new_script_tag.save
		    puts Colorize.cyan(asset.public_url)
		    puts Colorize.green('created script tag')
		  end
		end
	end

end