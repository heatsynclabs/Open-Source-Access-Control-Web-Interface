# Access cards (admin guide)

Cards open the doors. The door board keeps its own list of cards and checks each swipe
itself, so a change in the site only takes effect on the door after it is **uploaded** to
the board.

## Slots

The board stores cards in numbered places called **slots**. In the site, a card's ID is its
slot. New cards use slots 10 to 199. When you create a card, the form suggests the lowest
free slot; keep it unless you have a reason not to. A card's slot cannot be changed after it
is created: to move a card, delete it and create it again.

## Add a card for a member

1. Cards, then New card.
2. Pick the member, type the card number as the reader shows it (hex, up to 8 characters),
   leave the slot as suggested, Access "Enabled". Save.
3. On the card's page, press **Upload**. The site sends the card to the board, and door-api
   reads it back to check the board stored it.
4. The member's card now opens the doors. Ask them to try it.

## Disable a card (lost card, member paused)

1. Edit the card, set Access to "Disabled", save.
2. Press **Upload**. The board now refuses that card and logs it as a disabled card (`f`).

## Delete a card

Press Delete on the card. The site first clears the card's slot on the board, then deletes
it from the database. If the board does not confirm (for example door-api is down), the card
is **not** deleted and you see why; try again later. A deleted card cannot open the door.

## Upload all

"Upload all cards" on the Cards page writes every card to its slot. Use it after the board
has been replaced or reset, or to be sure the board matches the site. It writes the cards
one after another and shows OK or FAIL for each slot.

## Good to know

- **Card numbers:** the card number is the raw number from the reader. Two cards cannot share
  a number.
- **Card changes are recorded:** door-api records which admin uploaded or deleted a card, in
  its audit log.
- **Who can manage cards:** only admins. Members see their own cards.
- **If the door does not match the site:** the IT officers can compare the board's slots with
  the site (the operations folder has a script for it).
