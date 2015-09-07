class ITunesCore

  def self.shared
    Dispatch.once { @instance ||= new }
    @instance
  end

  attr_reader :itunes
  attr_accessor :playlists
  attr_accessor :local_playlists
  attr_accessor :selectable_playlists

  def initialize
    @itunes = SBApplication.applicationWithBundleIdentifier("com.apple.iTunes")

    # TODO check for empty library and add an empty song
  end

  def library_path
    return @library_path if @library_path

    apple_defaults = NSUserDefaults.alloc.init.persistentDomainForName('com.apple.iapps')

    itunes_xml_file = NSURL.URLWithString(apple_defaults["iTunesRecentDatabases"].last).path
    $log.info "Scanning the library XML file: #{itunes_xml_file}"

    @library_path = self.library_path_from_itunes_xml(itunes_xml_file)
    $log.info "iTunes Library: #{@library_path}"

    @library_path
  end

  def main_library_source
    @itunes.sources.get.detect { |s| s.send('kind') == CoreConstants::VTAiTunesLibrarySource }
  end

  def library_path_from_itunes_xml(xml_path)
    # <key>Music Folder</key><string>file://localhost/Volumes/Data/Media/</string>

    music_folder_xml = `grep '<key>Music Folder</key>' "#{xml_path}"`.strip
    file_url = music_folder_xml.match(/<string>(.*)<\/string>/)[1]

    $log.info "Found possible iTunes music: #{file_url}"

    # the path method strips out the ending slash
    library_path = NSURL.URLWithString(file_url).path + '/'

    # in my case, `library_path` this will return the path to the music folder
    # however, in Mark's case there is a folder 'Music' inside that folder

    [
      'Music/'
    ].each do |possible_sub_folder|
      possible_library_path = File.join(library_path, possible_sub_folder)  

      if File.exists?(possible_library_path)
        return possible_library_path
      end
    end

    library_path
  end

  def is_airplay_connected?
    # AirPlayEnabled
  end

  def is_playing?
    @itunes.playerState == CoreConstants::VTiTunesIsPlaying
  end

  def get_playlists
    self.playlists = main_library_source.userPlaylists.get.inject([]) do |a, p|
      if p.specialKind == CoreConstants::VTAiTunesSpecialNone && p.fileTracks.count > 0 && !p.smart
        a << PlaylistCore.new(p)
      end

      a
    end

    if defined?(ClientConstants)
      self.local_playlists = self.playlists.select do |p|
        p.name.start_with?(ClientConstants::GLOBAL_PLAYLIST_PREFIX) && p.fileTracks.count > 0
      end

      self.selectable_playlists = self.playlists.select { |p| p.name != 'Shuffle' && p.fileTracks.count > 0 }
    end

    @playlists
  end

  def get_playlist(name)
    get_playlists.detect { |p| p.name == name }
  end

  def main_library_source
    @itunes.sources.get.detect { |s| s.send('kind') == CoreConstants::VTAiTunesLibrarySource }
  end

  # == client methods

  def delete_smart_playlists
    delete_list = self.main_library_source.userPlaylists.select(&:smart)
    delete_list.count.times do |playlist|
      delete_list.pop.delete
    end
  end

  def delete_duplicate_playlists
    user_playlists = self.main_library_source.userPlaylists.select { |p| p.specialKind == CoreConstants::VTAiTunesSpecialNone }

    while !user_playlists.empty?
      # SB causes random memory errors:
      # popping a playlist off an array will *sometimes*
      # causes a double release error to occur

      playlist_name = user_playlists.last.name.copy

      user_playlists.pop

      user_playlists.reject! do |d|
        # same funkiness here to prevent double release errors
        # run delete without touching the object again

        if d.name == playlist_name
          d.delete
          true
        end

        false
      end
    end

    self.get_playlists
  end

  def delete_playlist(playlist_name)
    $log.info "Deleting playlist: #{playlist_name}"

    if get_playlist(playlist_name)
      self.main_library_source
        .userPlaylists
        .objectWithName(playlist_name)
        .delete

      self.get_playlists
    end
  end

  def create_playlist(name)
    playlist = self.get_playlist(name)

    if playlist.nil?
      playlist = @itunes.classForScriptingClass("playlist").alloc.initWithProperties "name" => name
      self.main_library_source.playlists.insertObject playlist, atIndex: 0
    else
      playlist = playlist.playlist
    end

    playlist      
  end

  def create_playlist_with_songs(playlist_name, song_file_list)
    delete_playlist(playlist_name)

    new_playlist = @itunes.classForScriptingClass("playlist").alloc.initWithProperties "name" => playlist_name
    main_library = self.main_library_source

    main_library.playlists.insertObject(new_playlist, atIndex: 0)

    # looks like a iTunes.add_to_(songList, newPlaylist) will not work on large playlists... not sure why
    # http://code.google.com/p/itunes-rails/source/browse/trunk/lib/itunes.rb?spec=svn86&r=86
    # http://www.cocoabuilder.com/archive/message/cocoa/2008/2/22/199695
            
    # add the song to the library THEN copy the track reference to the playlist

    song_file_list.each do |song_file|
      track_reference = self.add_song(song_file, main_library)

      track_reference.duplicateTo(new_playlist) unless track_reference.nil?
    end
  end

  # http://dougscripts.com/itunes/2010/12/get-a-track-reference-from-a-file-path/
  def add_songs(song_path_list, library_target = nil)
    library_target ||= self.main_library_source
    song_url_list = song_path_list.map { |p| NSURL.alloc.initFileURLWithPath(p) }

    @itunes.add song_url_list, to: library_target
  end

  def add_song(song_file_path, main_library = nil)
    song_file_url = NSURL.alloc.initFileURLWithPath(song_file_path)
    main_library ||= self.main_library_source

    track_reference = @itunes.add [song_file_url], to: main_library
    
    # TODO need to check if this still happens in the latest itunes
    # not sure why, but sometimes add_to_ returns a invalid reference
    if track_reference.nil?
      $log.error "iTunesError: Error adding track (#{song_file_url})"
    end

    track_reference
  end

end