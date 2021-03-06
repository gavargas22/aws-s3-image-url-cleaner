task :get_aws_urls => :environment do
  import 'sequel'

  def get_response_code(url)
    res = Net::HTTP.get_response(URI.parse(url))
    return res.code.to_i
  end

  def replace_old_url(new_url, media_object)
    print "Changing URL\n"
    byebug
    media_object.update(guid: new_url)
    print "Done!\n"
    # print media_object[:guid]
    # print new_url
  end

  # Connect to the database
  foreign_db = Sequel.connect(:adapter => 'mysql2', :user => ENV["mysql_user"], :password => ENV["mysql_password"], :host => ENV["mysql_url"], :database => 'wordpress')
  # Get all the posts
  posts = foreign_db.from(:gngdu_posts)
  # Obtain only the attachments
  media_posts = posts.where(:post_type => 'attachment', :post_date_gmt => (Date.today - 7.months)..(Date.today - 1.month))
  # Look up each individual post
  media_posts.each do |media|
    # Get the image URL from guid
    img_url = media[:guid]
    # Check if the original url contains an image
    res = Net::HTTP.get_response(URI.parse(img_url))
    # Read the response
    # If the url contains a valid image
    byebug
    if res.code.to_i == 200
      # Do nothing
      print "Image already had a correct URL\n"
    # Otherwise if the URL does not return an image...
    elsif res.code.to_i == 403
      # Get the metadata of the image
      year = media[:post_date_gmt].to_time.strftime('%Y')
      month = media[:post_date_gmt].to_time.strftime('%m')
      day = media[:post_date_gmt].to_time.strftime('%d')
      hour = media[:post_date_gmt].to_time.strftime('%H')
      minute = media[:post_date_gmt].to_time.strftime('%M')
      second = media[:post_date_gmt].to_time.strftime('%S')
      # Get the name of the image
      uri = URI.parse(media[:guid])
      filename = File.basename(uri.path)
      # Construct a new URL
      new_url_without_filename = 'https://s3.amazonaws.com/vanhorn-advocate/wp-content/uploads/' + year.to_s + '/' + month + '/' + day.to_s + hour.to_s + minute.to_s #/ClintonFlowers.jpg
      # Check a range of 60 seconds to see which url works
      # Initialize empty string to store new URL
      full_url_with_working_parameters = ""
      print("Looking for matching files\n")
      (0..60).each do |n|
        if get_response_code(new_url_without_filename + sprintf('%02d', n) + '/' + filename) == 200
          print("Found a match!\n")
          full_url_with_working_parameters = new_url_without_filename + sprintf('%02d', n) + '/' + filename
          # Change the URL of the old image to the new AWS
          # If the new URL did not return empty
          if !full_url_with_working_parameters.empty?
            # Change the URL of the image
            byebug
            replace_old_url(full_url_with_working_parameters, media)
          end
          break
        end
      end
    end
  end


end
