# Just shining products

This file will be used by LLMs, that chat with potential customers and sell the products on the website, as a knowledge base.

## Overview

'Just Shining' sells dishwashers, carefully selected from the market 
for their quality and efficiency.

There are six models. Each one is meant for a different kitchen or a different
household, so nearly every customer has one clear match. The work of the
assistant is to find that match with a few questions and then send the
customer to the landing page of that model.

## How to guide the customer to a model

Ask before recommending. Three or four short questions are usually enough, and
the answers rule out models faster in this order.

First, ask where the machine will go. If there is no place to connect it to
water and a drain, or the customer is renting and cannot change the kitchen,
the answer is the Mini and the other questions do not matter.

Second, ask how wide the gap is. Cabinets leave either 45 cm or 60 cm, and the
customer usually has to go and measure. A 45 cm gap means the Slim. A 60 cm
gap leaves four models, and the next questions choose between them.

Third, ask how many people eat at home and how often the dishes pile up. Five
or more people, or anyone who would run a normal machine twice in a day, wants
the Family.

Fourth, ask whether the kitchen is open to a room where people sleep, work, or
watch television, and whether cycles get started at night. Either one points
to the Silent.

Fifth, ask what the customer cares about more: the price on the day, or the
water and power the machine uses afterwards. The second answer points to the
Eco.

When nothing stands out, recommend the Classic. It is the cheapest full-size
model and it washes as well as the rest.

## Tie-breakers

* Narrow kitchen, large household: the Family does not fit a 45 cm gap. Sell
  the Slim and say plainly that it will need to run twice on busy days.
* Wants quiet and low consumption: the Silent is 39 dB and class A, the Eco is
  42 dB and uses 2.7 liters less per cycle. Ask which one the customer would
  notice, and sell that one.
* Budget under $500: the Mini is the only model in that range, and it holds
  6 place settings. Say so rather than stretching another model to fit.
* Torn between the Classic and the Family: the Family pays for itself in time,
  not money, if it saves a second cycle most days.
* Buying the Eco to save money: tell the customer the numbers on the landing
  page. The price difference takes years to come back, and it is better that
  they hear it now.

## Rules for the assistant

* Recommend one model. Name a second only as an alternative, and say what
  separates them. Do not list all six.
* Always give the link to the landing page of the model you recommend.
* Do not invent specifications, prices, discounts, or delivery dates. If the
  answer is not in this file or on the landing page, say that you will check.
* Do not claim a model is quieter, cheaper, or more efficient than a named
  competitor. Compare only within this range.
* If the customer has not measured the gap, ask them to. Recommending a 60 cm
  machine for a 45 cm gap is the one mistake that cannot be fixed after
  delivery.

## Terms that apply to every model

Prices are in US dollars and include delivery within five working days. Every
model has a two-year warranty on parts and labor; the Silent and the Eco have
five years on the motor. Unused machines can be returned within 30 days.

We do not install. Except for the Mini, which needs no installation, the
machine has to be connected to a cold water line and a drain, which takes a
plumber about an hour.

## Products

### Just Shining Mini

A countertop machine for 6 place settings that connects to the kitchen faucet
or runs from a 5 liter tank, so nothing is fitted under the cabinets. For
rented kitchens, studios, and offices. 49 dB. $329.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/mini.md)

### Just Shining Slim

A 45 cm machine for 10 place settings, for kitchens that have a water
connection but a narrow gap. Fits a household of two or three running it
daily. 44 dB, energy class C. $549.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/slim.md)

### Just Shining Classic

The standard 60 cm machine for 14 place settings, and the default
recommendation when nothing about the kitchen or the household is unusual. Its
quick 60 program washes and dries a normal load in an hour. 46 dB, energy
class C. $699.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/classic.md)

### Just Shining Family

A 60 cm machine with a taller tub and a third cutlery rack, holding 16 place
settings. For five people or more, or anyone who would otherwise run a cycle
twice a day. 44 dB, energy class B. $949.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/family.md)

### Just Shining Silent

A 60 cm machine for 14 place settings that runs at 39 dB, with a light on the
floor in place of the end-of-cycle beep. For kitchens open to a living room or
a bedroom, and for cycles that run overnight. Energy class A. $1,049.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/silent.md)

### Just Shining Eco

A 60 cm machine for 14 place settings that uses 6.8 liters and 0.62 kWh per
eco cycle, sets water and time by the weight and dirtiness of the load, and
dries without a heating element. For metered water and for customers who want
lower consumption. 42 dB, energy class A. $1,199.
[Landing page](https://github.com/polina-c/a2ui-spikes/blob/main/domain/landing_pages/eco.md)
