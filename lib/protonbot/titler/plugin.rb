require 'http'
require 'nokogiri'

ProtonBot::Plugin.new do
  @name        = "Titler"
  @version     = ProtonBot::Titler::VERSION
  @description = 'A URL resolver for ProtonBot. Filters most bots automatically, so no botloops.'

  hook(type: :privmsg) do |dat|
    #core.privmsg_patch(dat)
    unless /(bot|serv)/i.match("#{dat[:nick]}!#{dat[:user]}@#{dat[:host]}")
      regex = %r((?:(?:https?):\/\/)(?:\S+(?::\S*)?@)?(?:(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,}))\.?)(?::\d{2,5})?(?:[/?#]\S*)?)i
      pattern = "%N%B[ :NICK%N#:URLNUM %B|%N :OUT %B]%N"
      dat[:message].scan(regex)[0,5].each_with_index do |v, k|
        unless %r(http[s]?://).match(v)
          v = 'http://' + v
        end
        out = ''
        err = nil
        begin
          res  = HTTP.get(v)
          while [301, 302, 303, 307, 308].include? res.code
            res = HTTP.get(res["Location"])
          end
        rescue HTTP::ConnectionError => e
          err = e
        end
        if err
          dat.reply(pattern
            .gsub(':NICK', dat[:nick])
            .gsub(':URLNUM', (k+1).to_s)
            .gsub(':OUT', "%C%RED\u200B#{err.message}%N"))
        elsif [200, 201, 203, 204, 205, 206, 207, 208, 226, 304].include?(res.code) && res["Content-Type"][/text\/html.*/]
          body = res.body.to_s
          html = Nokogiri::HTML(body)
          dat.reply(pattern
            .gsub(':NICK', dat[:nick])
            .gsub(':URLNUM', (k+1).to_s)
            .gsub(':OUT', "%C%GREEN\u200B" + html.title.strip.gsub(/[\n\r]/, ' ')[0,100] + '%N'))
        else
          contenttype =
            if res["Content-Type"]
              ' %C%GREEN' + res["Content-Type"] + '%N'
            else
              ''
            end
          dat.reply(pattern
            .gsub(':NICK', dat[:nick])
            .gsub(':URLNUM', (k+1).to_s)
            .gsub(':OUT', "%C%ORANGE\u200B#{res.code}%N#{contenttype}"))
        end
      end
    end
  end
end