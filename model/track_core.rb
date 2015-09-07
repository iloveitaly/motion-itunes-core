class TrackCore
  attr_accessor :scheduledTime
  
  def initWithTrack(track)
    if self.init
      @track = track
      @lengthString = nil
      @trackCache = {}
      @scheduledTime = ""
      
      if track.playedDate
        begin
          @scheduledTime = @track.playedDate.descriptionWithCalendarFormat "%H:%M",
            timeZone: nil,
            locale: nil
        rescue Exception => e
          $log.error("Calendar error: #{e}")
        end
      end
    end
    
    return self
  end

  def lastPlayedTime
    # we were getting an error (under some inconsistent circumstances) without temp storing this variable
    playedDate = @track.playedDate
    
    if playedDate
      return playedDate.descriptionWithCalendarFormat "%d/%m/%y %H:%M",
        timeZone: nil,
        locale: nil
    else
      return "Never"
    end
  end
    
  def songLength
    return ClientConstants.formatIntToMinutesSeconds(@track.duration.to_i)
  end
  
  def rating
    return @track.rating.to_i / 20
  end
  
  def setRating(value)
    @track.setValue value * 20, forKey:"rating"
  end
  
  # trickyness
  
  def valueForUndefinedKey key
    if not @trackCache.has_key? key
      @trackCache[key] = @track.send(key.to_sym)
    end
    
    return @trackCache[key]
  end
  
  def method_missing sym, *args
    # puts "MISSING METHOD" + sym.to_s + " ARGS " + args.to_s
    
    symS = sym.to_s
    
    if symS == "delete"
      @track.delete
      return
    end
    
    if not @trackCache.has_key? symS
      @trackCache[symS] = @track.send(sym)
    end
    
    @trackCache[symS]
  end
end