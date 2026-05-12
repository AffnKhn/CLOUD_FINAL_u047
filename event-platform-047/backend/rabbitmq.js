const amqp = require('amqplib');

let channel;

async function connectRabbitMQ() {
  let retries = 15;
  while (retries > 0) {
    try {
      const connection = await amqp.connect(process.env.RABBITMQ_URL);
      channel = await connection.createChannel();
      await channel.assertQueue(process.env.QUEUE_NAME, { durable: true });
      console.log('RabbitMQ connected. Queue: ' + process.env.QUEUE_NAME);
      return;
    } catch (err) {
      console.log('RabbitMQ not ready, retrying... (' + retries + ' left)');
      retries--;
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  throw new Error('Could not connect to RabbitMQ after retries');
}

async function publishMessage(queue, message) {
  if (!channel) throw new Error('RabbitMQ channel not initialized');
  channel.sendToQueue(queue, Buffer.from(message), { persistent: true });
  console.log('Published to ' + queue + ': ' + message);
}

module.exports = { connectRabbitMQ, publishMessage };
