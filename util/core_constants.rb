module CoreConstants
  def self.makeNumberFromCharCode(code)
    return (code[0].ord << 24) | (code[1].ord << 16) | (code[2].ord << 8) | code[3].ord
  end

  VTAiTunesSpecialNone = makeNumberFromCharCode("kNon")
  VTAiTunesSpecialFolder = makeNumberFromCharCode("kSpF")
  VTAiTunesLibrarySource = makeNumberFromCharCode("kLib")
  VTiTunesIsPlaying = makeNumberFromCharCode('kPSP')

  LIVE_SERVER_TEST = true

  # TODO SERVER_HOST

  SERVER = "http://#{SERVER_HOST}/"
end
