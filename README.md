# hubot-twitter-userstream

hubot-twitter-userstream is an adapter for [Hubot](https://hubot.github.com/) that allows you to use the hubot with Twitter on user TL.

It differs from [hubot-twitter](https://github.com/MathildeLemee/hubot-twitter)...
* It can watch user timeline.
* It can receive and send direct message.
* It can follow and remove users.
* It can receive some events(favorited, followed, ...).

## Installation
    $ hubot --create myhubot
    $ cd myhubot
    $ npm install hubot-twitter-userstream --save && npm install

## Usage
At first, you will need to set some API keys.

    $ export HUBOT_TWITTER_KEY="key"
    $ export HUBOT_TWITTER_SECRET="secret"
    $ export HUBOT_TWITTER_TOKEN="token"
    $ export HUBOT_TWITTER_TOKEN_SECRET="secret"

## Messages
Properties of received message.
{
	id: <status_id>
	user: {id: <user_id>, name: <screen_name>, room: <"Twitter" or "TwitterDirectMessage"> },
	text: <body of message>
	data: <raw object of tweet or direct message>
}

## Events
favorited - {user: <user object to favorited user>, tweet: <favorited tweet>}
unfavorited - {user: <user object to unfavorited user>, tweet: <unfavorited tweet>}
The tweet is equal to target_object in https://dev.twitter.com/docs/streaming-apis/messages#Events_event .

followed - {user: <user object to followed user>}
unfollowed - {user: <user object to followed user>}

## Copyright
Copyright(c) 2014 hoo89 http://hoo89.hatenablog.com/ hoo89@me.com

This source licensed under the MIT license.
