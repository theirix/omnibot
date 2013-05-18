OmniBot
===============

Simple XMPP bot for server monitoring.
Works with AMQP for sending messages at server side.
Sends notifications to a user via XMPP.
Checks e-mail and extracts attachments to a specified
directory.

Dependencies
------------

 * RabbitMQ or any other AMQP-compatible server
 * amqp 
 * xmpp4r 
 * eventmachine
 * mail
 * sqlite3

Installation
------------

Configure omnibot configuration from examples/config.yaml to ~/.omnibot.yaml and adjust it.
Then execute command:

    omnibot

Send messages to omnibot by AMQP by running:

    omnisend 'Hello World!'

Support
-------

Tested with ruby 1.8.6, 1.9 and 2.0, rabbitmq as an AMQP server, at OS X 10.6+ and Debian Linux.
