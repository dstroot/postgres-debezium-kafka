const kafka = require("./kafka");
const sgMail = require("@sendgrid/mail");

if (process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

const consumer = kafka.consumer({
  groupId: process.env.GROUP_ID,
});

const run = async () => {
  await consumer.connect();

  await consumer.subscribe({
    topic: process.env.TOPIC,
    fromBeginning: true,
  });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      // const prefix = `${topic}[${partition} | ${message.offset}] / ${message.timestamp}`;
      // console.log(`- ${prefix} ${message.key}#${message.value}`);

      // log event
      const value = JSON.parse(message.value);
      console.log(value.payload);

      // send email
      if (
        value.payload.op === "c" &&
        process.env.SENDGRID_API_KEY // create, so new customer
      ) {
        console.log("\nNew Customer - Sending Email");
        console.log("\nTopic: " + topic);
        console.log("partition: " + partition);
        console.log("New Customer: " + value.payload.after.first_name);
        console.log("Customer Email: " + value.payload.after.email);

        const msg = {
          to: value.payload.after.email,
          from: "dan@thestroots.com",
          subject: `Welcome ${value.payload.after.first_name}!`,
          text: `Thanks for signing up ${value.payload.after.first_name}! We are thrilled to have you as a new customer.`,
          html: `<strong>Thanks for signing up ${value.payload.after.first_name}! We are thrilled to have you as a new customer.</strong>`,
        };

        sgMail
          .send(msg)
          .then(() => {
            console.log("email sent");
          })
          .catch((error) => {
            console.error(error);
          });
      }
    },
  });
};

run().catch((e) => console.error(`[example/consumer] ${e.message}`, e));

const errorTypes = ["unhandledRejection", "uncaughtException"];
const signalTraps = ["SIGTERM", "SIGINT", "SIGUSR2"];

errorTypes.forEach((type) => {
  process.on(type, async (e) => {
    try {
      console.log(`process.on ${type}`);
      console.error(e);
      await consumer.disconnect();
      process.exit(0);
    } catch (_) {
      process.exit(1);
    }
  });
});

signalTraps.forEach((type) => {
  process.once(type, async () => {
    try {
      await consumer.disconnect();
    } finally {
      process.kill(process.pid, type);
    }
  });
});
