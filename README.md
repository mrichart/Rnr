Rnr: Router-based Notification Router
===

Rnr is a Content-Based Publish-Subscribe notification bus.

## Topology

A Rnr node is a server process instance. It accepts TCP connection from other Rnr instances, or final clients.
Optionally, Rnr can also open a single connecton to another Rnr instance (upstream conection). 
Thus, a Rnr network is a tree (aciclic graph), where internal nodes are Rnr instances, and leaves are final clients.
There is single Rnr instance, the root of the tree, that has no upstream connection.

Usually, clients connect to closest Rnr instance (for example, on the same phisical node), tough this is not mandatory.

The simplest possible topology is a single Rnr instance, with no upstream, to which all final clients connect.


## Installation

To run Rnr you need [Lua 5.1](http://lua.org) [luasocket]i(http://w3.impa.br/~diego/software/luasocket/) installed. 
For example, under Debian/Ubuntu run:


    $ sudo apt-get install lua5.1
    $ sudo apt-get install liblua5.1-socket2

## Configuration

To configure Rnr, you write a configuration file. The configuration file is a plain Lua script, that assigns values 
to configuration parameters. If it doesn't, the parameter will have a default value.

The basic parameters are:

- my_host: The ip address where the server is listening (defaults to '127.0.0.1').
- rnr_port: the port where the serve is listening. (defaults to 8182)
- upstream: a table containing a upstream ip address (defaults to a empty table, {}). The upstream address is representes as an array {"ip", port}

A sample configuration archive, that listens on a network interace and has a upstream connection could be:

```lua
my_host='192.68.1.5'              -- the ip of my network interface
upstream[1]={'192.168.1.1', 8182} -- there should be a rnr instance running there
```

For more configuration parameters and their default values, check configuration.lua . Also remember that the configuration file is a lua script, so you can generate values programatically.


## Running

If you have your configuration in config.txt, then start Rnr as

    $ lua rnr.lua config.txt

## Messages

Messages are multi-line strings. They are case sensitive. A message starts
with a line with a message type identifier (SUBSCRIBE, UNSUBSCRIBE or
NOTIFICATION) and ends with a line containing the text END. To use the
rnr network is neccesary at least to implement the transmission of SUBSCRIBE
messages and the reception of NOTIFICATION messages.

### Notification

The notification is the message that carries information. It consists of a list of attribute=value
pairs. A sample notification is as follows:

```
NOTIFICATION
notification_id = notid
timestamp = 1234
anattrib = value
othertrib = another value
END
``` 

The _notification\_id_ is mandatory, and must be a unique id trough the network.

### Subscription

A subscription expresses the interest of a client on receiveing certain messages. 
A subscription is composed of a description and a filter. the filter is a list of predicates that a 
notification must match to be delivered to the client.
A sample subscription:

```
SUBSCRIBE
subscription_id=snid
FILTER
source = id01
a_name = big iron
price < 20
END

```

The _subscription\_id_ is mandatory, and must be a unique id trough the network.

To unsubscribe, a message as the following can be used.

```
UNSUBSCRIBE
subscription_id=snid
END

```

## License

See COPYRIGHT.


---
(c) Mina Group, Universidad de la República, Uruguay

jvisca@fing.edu.uy
