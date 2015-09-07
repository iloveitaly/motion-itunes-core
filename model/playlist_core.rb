class PlaylistCore
  attr_reader :playlist

  def initialize(itunes_playlist)
    @playlist = itunes_playlist
    @track_list = []

    unless self.name
      # @name = ""
      $log.error("Playlist does not have a valid name! Does playlist exist? %i" % @playlist.exists)
    end
  end

  def track_table
    @playlist.fileTracks.get.map do |file_track|
      {
        'location' => file_track.location.path.mutableCopy,
        'name' => file_track.name,
        'artist' => file_track.albumArtist || file_track.artist || "Unknown Artist",
        'id' => file_track.persistentID
      }
    end
  end

  def track_list
    self.normalize_tracks if @track_list.empty?
    @track_list
  end

  # cut off the global identifier
  def normalized_name
    @normalized_name ||= if self.name.start_with?(ClientConstants::GLOBAL_PLAYLIST_PREFIX)
      self.name[2..-1]
    else
      self.name
    end
  end

  def name
    @name ||= @playlist.name
  end
  
  def text_export
    self.normalize_tracks
    @track_list.join("\n")
  end

  def normalize_tracks
    # sometimes iTunes doesn't return the correct track reference
    # we count the amount of track references that contain errors
    # this number is used when compared the playlist data to the server
    # if the difference count & error count are the same we assume that the playlist is still complete

    return if !@track_list.empty? && @location_error_count == 0

    # sometimes iTunes doesn't return the correct track reference, we count the amount of track references that contain errors
    # this number is used when compared the playlist data to the server, if the difference count & error count are the same we assume that the playlist is still complete
    @location_error_count = 0
    
    file_path_list = []
    library_path = ITunesCore.shared.library_path
    
    # ITunesPlaylist does NOT have fileTracks
    # only user playlists have fileTracks

    @playlist.fileTracks.get.each do |track|
      location = track.location
      
      if location
        file_path_list << location.path.mutableCopy
      else
        $log.error("Bad track (%s) location (%s) in playlist (%s)" % [track.name, location, self.name])
        
        @location_error_count += 1
      end
    end

    # check if the playlist is empty
    return false if file_path_list.empty?

    file_path_list.each do |value|
      if value.include?(library_path)
        value.gsub!(library_path, '')
      end
    end
    
    # spot check the playlist normalization
    # because the library path ends with a slash (ALWAYS!)
    # we know that the first characer of any path to a song should NOT begin with a /
    
    if file_path_list[0][0] == '/'
      # then there might of been an error grabbing the correct library path
      $log.error("Possible iTunes library reference error %s, %s " % [library_path, file_path_list[0]])

      # TODO need to present an error to the user at this point
    end

    @track_list = file_path_list
  end
  
  def get_archive(exclude_list)
    library_path = ITunesCore.shared.library_path
    archive_file_path = NSFileManager.defaultManager.tempFilePath

    # compare with server list
    local_unique, server_unique = self.playlist_difference(exclude_list)

    if local_unique.empty?
      $log.info "All songs exist remotely; no archive needed"
      return false
    end

    $log.debug "Start Tar Archiving #{archive_file_path} with songs: #{local_unique}"
  
    # LC_ALL is VERY important here: without this a random decomposition will be used that will cause issues on the server
    result = IO.popen("LC_ALL=en_US.UTF-8 tar cfvz \"#{archive_file_path}\" --format=pax -C \"#{library_path}\" -T - ", "w+") do |tar|
      tar.puts local_unique.join("\n").strip
      tar.close_write
      tar.read
    end
    
    $log.debug "Tar Archive (#{archive_file_path}) Result: #{result}"
    
    archive_file_path
  end
  
  def equal_to_server_playlist?(server_content)
    left_difference, right_difference = self.playlist_difference(server_content)
    is_equal = left_difference.empty? && right_difference.empty?

    unless is_equal
      $log.info "Tracks unique to local: #{left_difference}"
      $log.info "Tracks unique to server: #{right_difference}"
    end

    is_equal
  end
  
  def playlist_difference(compare_list)
    # normalizing the character encoding is important
    # in the python days using NFD encoding was essential
    # with 1.9.2 ruby + UTF8 as default, things seem fine

    normalized_local = self.text_export.decomposedStringWithCanonicalMapping.split("\n").map(&:strip).sort
    normalized_compare = compare_list.decomposedStringWithCanonicalMapping.split("\n").map(&:strip).sort

    [
      # items unique to local
      normalized_local - normalized_compare,

      # items unique to server
      normalized_compare - normalized_local
    ]
  end

  # pass all undefined methods off to the iTunes Playlist
    
  # def valueForUndefinedKey key
  #   @playlist.send(key.to_sym)
  # end
  
  def method_missing(sym, *args)
    if args.length == 0
      @playlist.send sym
    end
  end
end
