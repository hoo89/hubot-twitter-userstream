Hubot   = require('hubot')
Twit = require('twit')

class Twitter extends Hubot.Adapter
  send: (envelope, strings...) ->
    strings.forEach (string) =>
      @bot.post 'statuses/update', {status: string}, (err, data, response) =>
        @robot.logger.error "twitter-userstream send error: #{err}" if err?

  reply: (envelope, strings...) ->
    strings.forEach (string) =>
      @bot.post 'statuses/update', {status: "@#{envelope.user.name} #{str}", in_reply_to_status_id:envelope.id}, (err, data, response) =>
        @robot.logger.error "twitter-userstream reply error: #{err}" if err?

  run: ->
    @client = new Twit {
      consumer_key	: process.env.HUBOT_TWITTER_KEY
      consumer_secret	: process.env.HUBOT_TWITTER_SECRET
      access_token	: process.env.HUBOT_TWITTER_TOKEN
      access_token_secret	: process.env.HUBOT_TWITTER_TOKEN_SECRET
    }

    @client.get 'account/verify_credentials', (err, user, response) =>
      if !err
        if user.screen_name != @robot.name
          console.warn """
            Your bot on Twitter is named as '#{user.screen_name}'.
            But this hubot is named as '#{@robot.name}'.
            To respond to mention correctly, it is recommended that #{`'\033[33mHUBOT_NAME='`}#{user.screen_name}#{`'\033[39m'`} is configured.
          """
      else
        "twitter-userstream run error: #{err}"

      bot  = @robot.brain.userForId(user.id, user.screen_name)

      stream = @client.stream('user')

      stream.on 'tweet', (tweet) =>
        return if bot.id == tweet.user.id
        user = @robot.brain.userForId tweet.user.id, name: tweet.user.screen_name, room: 'Twitter'
        tmsg = new Hubot.TextMessage(user, tweet.text, tweet.id)
        @receive tmsg
      @emit 'connected'

exports.use = (robot) ->
  new Twitter robot

