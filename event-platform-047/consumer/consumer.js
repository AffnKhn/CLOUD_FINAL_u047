require('dotenv').config();
const amqp = require('amqplib');

async function startConsumer() {
  let retries = 20;
  while (retries > 0) {
    try {
      const connection = await amqp.connect(process.env.RABBITMQ_URL);
      const channel = await connection.createChannel();
      await channel.assertQueue(process.env.QUEUE_NAME, { durable: true });
      channel.prefetch(1);
      console.log('[consumer_047] Listening on queue: ' + process.env.QUEUE_NAME);

      channel.consume(process.env.QUEUE_NAME, (msg) => {
        if (msg) {
          const data = JSON.parse(msg.content.toString());
          console.log(
            "[consumer_047] Notification sent: New event '" +
            data.title + "' created in region '" +
            data.region + "' (event_id=" + data.event_id + ")"
          );
          channel.ack(msg);
        }
      });
      return;
    } catch (err) {
      console.log('[consumer_047] RabbitMQ not ready, retrying... (' + retries + ' left)');
      retries--;
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  console.error('[consumer_047] Failed to connect to RabbitMQ');
  process.exit(1);
}

startConsumer();
