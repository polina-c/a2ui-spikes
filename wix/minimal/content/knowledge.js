/**
 * What the assistant knows about your site.
 *
 * This is the only file you edit to change the answers. build.sh folds it into
 * embed/chat.html and embed/ai-chat.velo.js, so both ways of putting the widget
 * on a Wix page pick it up with no further steps.
 *
 * Write plain sentences, the way you would answer a customer. Keep each entry
 * to one subject and give it a title that names that subject, because the title
 * is what gets matched when there is too much content to send at once.
 *
 * Replace everything below with your own business. The studio is made up.
 */
window.AI_CHAT_KNOWLEDGE = [
  {
    title: "What Northwind Studio does",
    text:
      "Northwind Studio is a portrait and product photography studio in " +
      "Portland, Oregon. We shoot headshots for individuals and teams, " +
      "product photography for online shops, and small events. We do not " +
      "shoot weddings.",
  },
  {
    title: "Prices and packages",
    text:
      "A single headshot session is $180 and includes three retouched " +
      "photos. Team headshots are $120 per person for groups of four or " +
      "more. Product photography starts at $40 per item, with a minimum of " +
      "ten items. Event coverage is $300 for the first two hours and $100 " +
      "for each hour after that.",
  },
  {
    title: "Opening hours",
    text:
      "The studio is open Tuesday to Saturday, 9am to 6pm. We are closed " +
      "Sunday and Monday. Evening sessions can be booked on request.",
  },
  {
    title: "How to book",
    text:
      "Book through the contact form on this site, or email " +
      "hello@northwindstudio.example. We usually reply within one business " +
      "day. A session is held once a 50% deposit is paid, and the deposit " +
      "is refundable up to 48 hours before the session.",
  },
  {
    title: "Where we are and parking",
    text:
      "The studio is at 118 NE Alberta Street, Portland. There is free " +
      "street parking on Alberta and a paid lot one block east. The nearest " +
      "bus stop is Alberta and NE 14th.",
  },
  {
    title: "Turnaround and delivery",
    text:
      "Edited photos arrive as a private online gallery within five business " +
      "days. Rush delivery in 48 hours costs an extra $75. You get full " +
      "rights to use the photos for your own business.",
  },
];
