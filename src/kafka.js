const { Kafka, logLevel } = require("kafkajs");
require("dotenv").config();

const ip = require("ip");
const host = process.env.HOST_IP || ip.address();
// console.log(host);

const kafka = new Kafka({
  logLevel: logLevel.INFO,
  clientId: "node-consumer",
  brokers: [`${host}:9092`],
});

module.exports = kafka;
