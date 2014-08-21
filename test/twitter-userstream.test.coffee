assert = require 'assert'
nock = require 'nock'
querystring = require 'querystring'

MockRobot = require './mock/robot'
Tweet = require './case/tweet'

Adapter = require '../'


process.env.HUBOT_LOG_LEVEL = 'ALERT'

describe 'hubot-twitter-userstream', ->
  robot = null
  adapter = null

  beforeEach ->
    process.env.HUBOT_TWITTER_KEY = 'example'
    process.env.HUBOT_TWITTER_SECRET = 'example'
    process.env.HUBOT_TWITTER_TOKEN = 'example'
    process.env.HUBOT_TWITTER_TOKEN_SECRET = 'example'

    nock('https://api.twitter.com')
      .get('/1.1/account/verify_credentials.json')
      .reply(200, Tweet.account_verify_credentials);

    robot = new MockRobot(Adapter)
    adapter = robot.adapter

  describe '#run', ->
    it 'should raise error when Access Token or API key missing', ->
      process.env.HUBOT_TWITTER_KEY = null

      assert.throws ->
        robot.run()
      ,/Twitter Access Token and API key are required./

    it 'should emit connected event', (done) ->
      adapter.on 'connected', done
      robot.run()

    it 'should receive tweet', (done) ->
      robot.receive = (msg) ->
        delete msg.data
        assert.deepEqual msg, {
          user: { id: 416981850, name: 'ju_no89', room: 'Twitter' },
          text: 'test .',
          id: '480605213426860032',
          done: false,
          room: 'Twitter'
        }
        done()

      nock('https://userstream.twitter.com')
        .post('/1.1/user.json')
        .reply(200, JSON.stringify(Tweet.tweet)+"\r\n")

      robot.run()

    it 'should receive direct message', (done) ->
      robot.receive = (msg) ->
        delete msg.data
        assert.deepEqual msg, {
          user: { id: 416981850, name: 'ju_no89', room: 'TwitterDirectMessage' },
          text: '@Hubot time',
          id: '480454960484593665',
          done: false,
          room: 'TwitterDirectMessage'
        }
        done()

      nock('https://userstream.twitter.com')
        .post('/1.1/user.json')
        .reply(200, JSON.stringify(Tweet.directMessage)+"\r\n")

      robot.run()

    it 'should emit favorite event on robot', (done) ->
      robot.on 'favorited', (event) ->
        assert.equal event.tweet.user.screen_name, 'busitu_now'
        delete event.tweet
        assert.deepEqual event, {
          user: { id: 19368158, name: 'hoo89', room: 'Twitter' }
        }
        done()

      nock('https://userstream.twitter.com')
        .post('/1.1/user.json')
        .reply(200, JSON.stringify(Tweet.favorite)+"\r\n")

      robot.run()

  context 'After connected', ->
    envelope = null

    beforeEach (done) ->
      robot.run()
      adapter.on 'connected', done

      envelope = {
        tweet : { 
          room: 'Twitter',
          user: { id: 416981850, name: 'ju_no89', room: 'Twitter' },
          message: {
            user: { id: 416981850, name: 'ju_no89', room: 'Twitter' },
            text: 'yunotti',
            id: '480605213426860032',
            done: false,
            room: 'Twitter'
          }
        }

        direct_message : {
          room: 'TwitterDirectMessage',
          user: { id: 416981850, name: 'ju_no89', room: 'Twitter' },
          message: {
            user: { id: 416981850, name: 'ju_no89', room: 'Twitter' },
            text: 'miyako',
            id: '480454960484593665',
            done: false,
            room: 'TwitterDirectMessage'
          }
        }
      }

    describe '#send', ->
      it 'should send tweet', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/statuses/update.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {status: 'test'}
            done()

        adapter.send(envelope.tweet, 'test')

      it 'should reply when respond to direct message', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/direct_messages/new.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {text: 'test', user_id:'416981850'}
            done()

        adapter.send(envelope.direct_message, 'test')

      it 'should cut tweet to 140 characters, if tweet is too long', (done) ->
        longer = Array(142).join('a')

        nock('https://api.twitter.com')
          .post('/1.1/statuses/update.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.equal request.status.length, 140
            done()

        adapter.send(envelope.tweet, longer)

      it "shouldn't interrupt URL", (done) ->
        longer = 'https://www.google.com/calendar/render ' + Array(142).join('a')

        nock('https://api.twitter.com')
          .post('/1.1/statuses/update.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.equal request.status.length, 155 #38+(140-23)
            done()

        adapter.send(envelope.tweet, longer)

    describe '#reply', ->
      it 'should reply to tweet', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/statuses/update.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {status: '@ju_no89 test', in_reply_to_status_id:'480605213426860032'}
            done()

        adapter.reply(envelope.tweet, 'test')

      it 'should reply to direct message', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/direct_messages/new.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {text: 'test', user_id:'416981850'}
            done()

        adapter.reply(envelope.direct_message, 'test')

    describe '#join', ->
      it 'should follow user when passed the user as argument', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/friendships/create.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {"user_id":"416981850"}
            done()

        user = { id: 416981850, name: 'ju_no89', room: 'Twitter' }
        adapter.join(user)

    describe '#part', ->
      it 'should remove user when passed the user as argument', (done) ->
        nock('https://api.twitter.com')
          .post('/1.1/friendships/destroy.json')
          .reply 200, (uri, body) ->
            request = querystring.parse(body)
            assert.deepEqual request, {"user_id":"416981850"}
            done()

        user = { id: 416981850, name: 'ju_no89', room: 'Twitter' }
        adapter.part(user)
