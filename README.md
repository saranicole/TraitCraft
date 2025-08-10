# TraitCraft

## A Console and PC Addon for Elder Scrolls Online

### What Does it Do for Me?

Tired of writing down which traits you need across which alts so that you can craft them on your main and research them on your alts?  This addon is for you!

Currently shows the unresearched traits on the research tab.

<img width="318" height="756" alt="TraitCraft_screenshot" src="https://github.com/user-attachments/assets/5fe33590-cdb0-4c8e-9774-f14feb4768b1" />

Screenshot courtesy of [MaliBuuGaming](https://www.esoui.com/forums/member.php?u=83968)


### Roadmap

* Autocraft option
* Possibly show traits on banked items (similar to TraitBuddy)

### How to Use
1. Log into your main crafter ( the one with the most traits researched already )
2. Install TraitCraft (or reset its saved variables from the "Manage My Addons" tab)
3. Select your crafters from the addon menu
4. Select your actively researching character(s) from the dropdown and select an icon for it - that icon will show up in the research tab of your selected crafters next to the trait they need
5. Click "Apply Settings" - note that settings do not automatically apply in this addon's menu
6. Log onto the actively researching character(s) - this can be quick, just log on and you don't have to do anything else
7. Log back onto the desired crafter
8. Open a crafting interaction
9. Open the Research view
10. See the icon(s) of the actively researching character(s) next to their needed traits - you will need to manually craft for now

### How it works

In order to operate within the limits of console addons and compress the trait table, the traits have been loaded into saved variables with their "key" set to a combined number which represents the known state of all the actively researching characters.  To accomplish this, each character is assigned a number which is 2 to the power of their order in the character lineup.  When the traits are scanned, this number is tested for in the existing trait value.  If a character now knows the trait but its power of two number is not present (or in bitwise math, its bit is not turned on), the power of two number is added.  Then when the research traits are loaded with the crafting character, the power of two number can be tested for again and the specific number identified.

Example:
Character 1 → mask = 1   2^0 (since bitwise math operates on a zero index)
Character 2 → mask = 2   2^1
Character 3 → mask = 4   2^2
Character 4 → mask = 8   2^3
Character 5 → mask = 16  2^4
Character 6 → mask = 32  2^5
Character 7 → mask = 64  2^6

This corresponds to binary numbers when added up - for instance, if characters 3 and 4 know a trait, their combined binary number is 1100, and their decimal number is 12.

If character 3 learns the trait, I can subtract 4 from 12 to get 8, and later test the value with the following function:

(trait % (mask*2)) < mask

or with real numbers:

(8 % (4*2)) < 4  

(8 % (8)) < 4

0 < 4

The result is that the trait table can contain the needed information, while only consisting of trait keys (crafting type * 10000 + research line * 100 + trait index) set to this combined character summary.  Super compact and suitable for use on consoles!

### Thanks, Credit, and Inspiration

I give credit to Baertram and the other developers ingeniousclown, katkat42, and Randactyl who developed [LibResearch](https://www.esoui.com/downloads/info517-LibResearch.html) and [Research Assistant](https://www.esoui.com/downloads/info111-ResearchAssistantFindyourresearchableitems.html), some code of which I used and modified.  When I get to the autocraft feature I will no doubt look at [Dolgubon's Lazy Writ Crafter](https://www.esoui.com/downloads/info1346-DolgubonsLazyWritCrafter.html) by Dolgubon as well.

Special thanks to [MaliBuuGaming](https://www.esoui.com/forums/member.php?u=83968) for the original ESO UI post that got me thinking about this problem in ESO, and for alpha testing some very unstable releases. 

### Requirements

Requires LibHarvensAddonSettings

### Development Status

Development Status is working with known bugs, install at your own risk!
