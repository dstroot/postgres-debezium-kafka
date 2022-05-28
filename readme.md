# Database updates coupled with event-driven architecture

Imagine a "customer" microservice that adds new customers to your customer database, and updates customer data as it changes.

Now, you decide to send all new customers an email welcoming them to your company/serice. The first choice you might think of is to enhance your customer microservice to send an email when a customer signs up. So, you integrate a transactional email service like SendGrid into your customer microservice and start sending welcome emails as customers sign up.

Problems start to occur though. One day SendGrid is down so when the customer microservice tries to send an email it fails, so the customer microservice fails overall, and customers are unable to sign up, even though the customer database is up and running. So you decide to enhance the code to handle this failure scenario - you decide to go ahead and write the customer to the database anyway and process the new customer signup, skipping the email if SendGrid is down. That way customers will "always" be able to sign up.

This causes two new issues. The first is obvious - how do I know which customers received a welcome email and which didn't? We could create some type of email error logging and write another microservice to watch the log for customers whose welcome email failed. Then retry sending them a welcome email - but this is getting complicated, right? The other issue is what happens if our database is down? What if the customer write failed, but I sent a welcome email anyway? Is this handled properly in the code?

However I don't just want to send a welcome email when a new customer signs up - imagine I have many things that need to happen:

- Send welcome email
- Setup customer in the billing system
- Update customer analytics with customer activity
- Etc.

How do keep the customer microservice "micro" and decoupled from all these other things? You make the customer microservice **only** responsible for adding the new customer to the customer database, then you publish the "new customer" event with the information about the customer to a "new customer even queue". Any other microservices like the Welcome Email service can subscribe to the event queue and respond to new customer events. Subscribers to the new customer even queue can be added or subtracted with ever touching the customer microservice. Things are completely decoupled. If the Welcome Email service fails, it can be restarted and pick up where it left off. It can also retry as necessary.

## Architecture

This repo uses:

- [Postgres](https://www.postgresql.org) as our main database
- [Debezium](https://debezium.io) for Change Data Capture (CDC) to send database events to
- Apache [Kafka](https://kafka.apache.org) as our "Event Queue", managed by
- [Zookeeper](https://zookeeper.apache.org) and
- A simple [Nodejs](https://nodejs.org/en/) application to consume events, leveraging
- [Kafkajs](https://kafka.js.org/) to connect Node to Kafka, and
- [SendGrid](https://sendgrid.com/) to send email.

Everything except the NodeJS app will be inside docker containers, so I created a single docker-compose.yml file that will instantiate everything.

### Why use a Publish/Subscribe (Pub/Sub) Messaging System like Kafka vs. a Message Broker like RabbitMQ?

For our purposes Kafka seems like a better fit, but it's "exactly once" processing is based on a transaction model that was added later - Kafka was orginally suited for "at least once" semantics.

#### What is Kafka?

Kafka is an open-source distributed event streaming platform, facilitating raw throughput. Written in Java and Scala, Kafka is a pub/sub message bus geared towards streams and high-ingress data replay. Rather than relying on a message queue, Kafka appends messages to the log and leaves them there, where they remain until the consumer reads it or reaches its retention limit. Kafka employs a “pull-based” approach, letting users request message batches from specific offsets. Users can leverage message batching for higher throughput and effective message delivery.

For our "Welcome Email" service we could use Kakfa. The service could pull unprocessed events, and send a welcome email, and if the email failed, we would not move the offset forward. We would keep retrying until success, and then we would move the offset forward to process newer events. Kafka can also more easily support multiple subscribers to a single event queue.

#### What is RabbitMQ?

RabbitMQ is an open-source message broker that facilitates efficient message delivery in complex routing scenarios. RabbitMQ employs a push model and prevents overwhelming users via the consumer configured prefetch limit. This model is an ideal approach for low-latency messaging. It also functions well with the RabbitMQ queue-based architecture. Think of RabbitMQ as a post office, which receives, stores, and delivers mail (and the mail is binary data messages). It is great for "exactly once" processing between one producer and one consumer.

For our "Welcome Email" service we could use RabbitMQ. If we received a new customer event and tried to send a welcome email, and the email failed, we would have write the new customer event back to the RabbitMQ event queue to pick up and process later. If it failed again we'd have to write back to the queue again potentially creating a loop.

#### Differences

| Kafka vs RabbitMQ | RabbitMQ                                            | Kafka                              |
| ----------------- | --------------------------------------------------- | ---------------------------------- |
| Performance       | 4K-10K messages per second                          | 1 million messages per second      |
| Message Retention | Acknowledgment based                                | Policy-based (e.g., 30 days)       |
| Data Type         | Transactional                                       | Operational                        |
| Consumer Mode     | Smart broker/dumb consumer                          | Dumb broker/smart consumer         |
| Topology          | Exchange type: Direct, Fan out, Topic, Header-based | Publish/subscribe based            |
| Payload Size      | No constraints                                      | Default 1MB limit                  |
| Usage Cases       | Simple use cases                                    | Massive data/high throughput cases |

## Process Flow

New user signs up -> Postgres -> Debezium -> Kafka -> Node Event Consumer -> SendGrid -> New User receives email

![Architecture](/img/architecture.png)

## Instructions

The core services will run inside Docker, however you will run the Nodejs even consumer locally. So to instantiate the Docker containers the docker-compose file, and the Nodejs app needs to know the IP address of your local machine.

You can either add it to your .env file or set the HOST_IP address (environment variable) this way:

`export HOST_IP=$(ifconfig | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v 127.0.0.1 | awk '{print $2}' | cut -f2 -d: |head -n1)`

### 1. Bring up the Docker Environment

Run: `docker-compose up -d`

This will start:

1. **Zookeeper** — Zookeeper keeps track of the status of the Kafka cluster nodes and it also keeps track of Kafka topics, partitions, etc. Zookeeper allows multiple clients to perform simultaneous reads and writes and acts as a shared configuration service within the system.
2. **Kafka** — Apache Kafka server
3. **Postgres** — Postgres database
4. **Debezium** — Debezium connect instance used for Change Data Capture

### 2. Instantiate the Debezium connector

Debezium is built upon the Apache Kafka project and uses Kafka to transport the changes from one system to another. It utilizes the change data capture pattern.

Debezium has a REST endpoint which we can use to see which connectors are enabled:

$> `curl -H "Accept:application/json" localhost:9090/connectors/`

This will return an empty array "[ ]" if everything is good. Now we will send the service a JSON configuration file that will connect it to Postgres, and tell it to listen specifically to the "customers" table:

$> `curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:9090/connectors/ -d @pg-source-config.json`

This should return a "HTTP/1.1 201 Created" response. If so we are good to go.

### 3. Start the Node consumer

If you want to actually send emails you will need a SendGrid API key - add it to the .env file. This is out of the scope of this readme.

$> `node ./src/index.js`

This should show the sample data that was loaded in when we created our postgres container:

```JSON
{
  before: null,
  after: {
    id: 1,
    first_name: 'Fred',
    last_name: 'Flintstone',
    email: 'fred@gmail.com',
    active: true,
    created: '2022-05-28T15:53:15.655263Z',
    updated: '2022-05-28T15:53:15.655263Z'
  },
  source: {
    version: '1.9.2.Final',
    connector: 'postgresql',
    name: 'postgres',
    ts_ms: 1653753215439,
    snapshot: 'last',
    db: 'postgres',
    sequence: '[null,"36218608"]',
    schema: 'public',
    table: 'customer',
    txId: 769,
    lsn: 36218608,
    xmin: null
  },
  op: 'r',
  ts_ms: 1653753215442,
  transaction: null
}
```

### 4. Test using pgadmin

Now open a browser and navigate to "localhost:3000" and pgadmin4 should open. This is the postgress admin tool. If you haven't used it before google it.

Open the server and database (everything should be already configured). Then, take a look at the "startup.sql" file in this repo. At the bottom of the file are some tests that have been commented out. You can use them to test this process end-to-end. Just paste into pgadmin in the SQL pane, uncomment, and run.

This simulates a microservice updating the customers table in our database.

enjoy!

## References

- [Thorough Introduction to Apache Kafka](https://hackernoon.com/thorough-introduction-to-apache-kafka-6fbf2989bbc1)
- [Listen to Postgres Changes with Apache Kafka](https://medium.com/geekculture/listen-to-database-changes-with-apache-kafka-35440a3344f0)
