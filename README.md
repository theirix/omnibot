OmniBot
===============

Simple XMPP bot for server monitoring.
Works with AMQP for sending messages at server side.
Sends notifications to a user via XMPP.

Dependencies
------------

 * RabbitMQ or any other AMQP-compatible server
 * amqp 
 * xmpp4r 
 * eventmachine

Installation
------------

Configure omnibot configuration from examples/config.yaml to ~/.omnibot.yaml and adjust it.
Then execute command:

    omnibot

Send messages to omnibot by AMQP by running:

    omnisend 'Hello World!'

Support
-------

Tested on Mac OS X 10.6 with Ruby 1.8