Hubot   = require 'hubot'
Twit = require 'twit'
TwitterText = require 'twitter-text'

class Twitter extends Hubot.Adapter
  send: (envelope, strings...) ->
    strings.forEach (string) =>
      if envelope.room != 'TwitterDirectMessage'
        @_postTweet string
      else
        @_postDirectMessage string, envelope.user.id

  sendPrivate: (envelope, strings...) ->
    strings.forEach (string) =>
      @_postDirectMessage string, envelope.user.id

  reply: (envelope, strings...) ->
    strings.forEach (string) =>
      if envelope.room != 'TwitterDirectMessage'
        @_postTweet "@#{envelope.user.name} #{string}", envelope.message.id
      else
        @_postDirectMessage string, envelope.user.id

  join: (user) ->
    @client.post 'friendships/create', {user_id: user.id}, (err, data, response) =>
      @robot.logger.error "twitter-userstream join error: #{err}" if err?

  part: (user) ->
    @client.post 'friendships/destroy', {user_id: user.id}, (err, data, response) =>
      @robot.logger.error "twitter-userstream part error: #{err}" if err?

  run: ->
    keys = {
      consumer_key  : process.env.HUBOT_TWITTER_KEY
      consumer_secret : process.env.HUBOT_TWITTER_SECRET
      access_token  : process.env.HUBOT_TWITTER_TOKEN
      access_token_secret : process.env.HUBOT_TWITTER_TOKEN_SECRET
    }

    for key of keys
      if keys[key] == 'null'
        @emit 'error', new Error('Twitter Access Token and API key are required. Please set environment variables HUBOT_TWITTER_*.')
        break

    @client = new Twit(keys)

    @client.get 'account/verify_credentials', (err, user, response) =>
      if err
        @robot.logger.error "twitter-userstream run error: #{err}"
      else
        @botUser = @robot.brain.userForId user.id, {name: user.screen_name, room: 'Twitter'}

        if user.screen_name != @robot.name
          @robot.logger.warning """
            Your bot on Twitter is named as '#{user.screen_name}'.
            But this hubot is named as '#{@robot.name}'.
            To respond to mention correctly, it is recommended that #{`'\033[33mHUBOT_NAME='`}#{user.screen_name}#{`'\033[39m'`} is configured.
          """

      stream = @client.stream('user')

      stream.on 'tweet', (tweet) =>
        return if @botUser.id == tweet.user.id
        user = @robot.brain.userForId tweet.user.id, {name: tweet.user.screen_name, room: 'Twitter'}
        tmsg = new Hubot.TextMessage(user, tweet.text, tweet.id_str)
        tmsg.data = tweet
        @receive tmsg

      stream.on 'direct_message', (message) =>
        message = message.direct_message
        return if @botUser.id == message.sender.id
        user = @robot.brain.userForId message.sender.id, {name: message.sender.screen_name, room: 'TwitterDirectMessage'}
        tmsg = new Hubot.TextMessage(user, "@#{@robot.name} #{message.text}", message.id_str)
        tmsg.data = message
        @receive tmsg

      stream.on 'user_event', (event) =>
        return if @botUser.id == event.source.id
        switch event.event
          when 'favorite'
            @robot.emit 'favorited', {
              user: @robot.brain.userForId event.source.id, {name: event.source.screen_name, room: 'Twitter'}
              tweet: event.target_object
            }
          when 'unfavorite'
            @robot.emit 'unfavorited', {
              user: @robot.brain.userForId event.source.id, {name: event.source.screen_name, room: 'Twitter'}
              tweet: event.target_object
            }
          when 'follow'
            @robot.emit 'followed', {
              user: @robot.brain.userForId event.source.id, {name: event.source.screen_name, room: 'Twitter'}
            }
          when 'unfollow'
            @robot.emit 'unfollowed', {
              user: @robot.brain.userForId event.source.id, {name: event.source.screen_name, room: 'Twitter'}
            }

      @emit 'connected'
      @robot.logger.info 'Connected with Twitter.'

  _postTweet: (text, replyId) ->
    if @_getTweetLength(text) > 140
      @robot.logger.warning 'The text of your tweet is too long.'
      text = @_cutTweet(text)

    @client.post 'statuses/update', {status: text, in_reply_to_status_id: replyId}, (err, data, response) =>
      @robot.logger.error "twitter-userstream error: #{err}" if err?

  _postDirectMessage: (text, userId) ->
    if @_getTweetLength(text) > 140
      @robot.logger.warning 'The text of your tweet is too long.'
      text = @_cutTweet(text)

    @client.post 'direct_messages/new', {text: text, user_id: userId}, (err, data, response) =>
      @robot.logger.error "twitter-userstream error: #{err}" if err?

  _getTweetLength: (text) ->
    TwitterText.getTweetLength(text)

  _cutTweet: (text) ->
    # If tweet is longer than 140 chars, twittter-userstream try to post message as long as possible.
    # But included URL is not interrupted.

    if TwitterText.getTweetLength(text) <= 140
      text
    else
      urls = TwitterText.extractUrlsWithIndices text
      if urls.length == 0
        text.slice(0,140)
      else
        str = ""
        strs = []
        cursor = 0
        for i in urls
          strs.push {is_url: false, text: text.slice(cursor, i.indices[0])}
          strs.push {is_url: true, text: text.slice(i.indices[0], i.indices[1])}
          cursor = i.indices[1]
        strs.push {is_url: false, text: text.slice(cursor)}

        left = 140
        for i in strs
          if i.is_url
            if left >= 23
              str = str.concat(i.text)
              left = 140 - TwitterText.getTweetLength(str)
            else
              break
          else
            if left > 0
              i.text = i.text.slice(0, left)
              str = str.concat(i.text)
              left = 140 - TwitterText.getTweetLength(str)
            else
              break

        str

exports.use = (robot) ->
  new Twitter(robot)
