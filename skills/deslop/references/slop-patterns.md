# Slop Patterns Reference

Exhaustive list of AI-generated writing patterns to detect and remove.
Organized by category with confidence levels.

- **High**: Always flag. These are slop in virtually any context.
- **Medium**: Flag but check context. May have legitimate uses.

---

## 1. Filler Phrases (High Confidence)

Phrases that add no meaning. Remove entirely and tighten the sentence.

| Pattern | Replacement |
|---|---|
| It's important to note that | (remove) |
| It's worth noting that | (remove) |
| It should be noted that | (remove) |
| It's worth mentioning that | (remove) |
| It bears mentioning that | (remove) |
| In order to | To |
| As a matter of fact | (remove) |
| At the end of the day | (remove) |
| When it comes to | For / With / In |
| In terms of | For / In |
| The fact that | (remove, restructure) |
| Due to the fact that | Because |
| In light of the fact that | Because / Since |
| On the other hand | (remove, or use "But" / "However") |
| With that being said | (remove) |
| That being said | (remove) |
| Having said that | (remove) |
| All things considered | (remove) |
| At this point in time | Now |
| For all intents and purposes | (remove) |
| In the realm of | In |
| In today's world | (remove) |
| In today's landscape | (remove) |
| In today's fast-paced world | (remove) |
| Needless to say | (remove -- if needless, don't say it) |
| As previously mentioned | (remove) |
| As we discussed | (remove) |
| Let's take a closer look at | (remove) |
| Let's explore | (remove) |
| Without further ado | (remove) |
| Last but not least | (remove, or use "Finally") |
| First and foremost | First |
| Each and every | Each / Every |
| By and large | (remove, or use "Generally") |
| Serves as a | Is a |
| Acts as a | Is a |

---

## 2. Unnecessary Adverbs and Intensifiers (High Confidence)

Words that weaken rather than strengthen. Remove the adverb; the verb is
enough.

| Pattern | Replacement |
|---|---|
| effectively | (remove) |
| essentially | (remove) |
| basically | (remove) |
| fundamentally | (remove) |
| incredibly | (remove) |
| extremely | (remove) |
| very | (remove) |
| really | (remove) |
| truly | (remove) |
| actually | (remove) |
| literally | (remove, unless literal) |
| simply | (remove) |
| just | (remove, unless meaning "fair") |
| quite | (remove) |
| rather | (remove) |
| highly | (remove) |
| vastly | (remove) |
| significantly | (remove, unless quantified) |
| dramatically | (remove, unless quantified) |
| remarkably | (remove) |
| notably | (remove) |
| particularly | (remove, unless distinguishing) |
| especially | (remove, unless distinguishing) |
| certainly | (remove) |
| definitely | (remove) |

---

## 3. Marketing and Hype Words (Medium Confidence)

Often slop in documentation and READMEs, but sometimes valid in engineering
contexts. Check whether the word is used precisely or as empty amplification.

| Pattern | Slop when... | Valid when... |
|---|---|---|
| robust | describing anything generically | describing fault tolerance, error handling |
| powerful | used as generic praise | describing computational capability |
| seamless | used as generic praise | describing integration with zero user friction |
| cutting-edge | used to describe any tech | (rarely valid -- prefer "recent" or be specific) |
| state-of-the-art | used generically | citing a specific benchmark or paper |
| innovative | used as generic praise | (rarely valid -- describe what's new instead) |
| revolutionary | used for anything | (almost never valid) |
| game-changing | used for anything | (almost never valid) |
| world-class | used for anything | (almost never valid) |
| best-in-class | used generically | citing a specific comparison |
| next-generation | used generically | (prefer specific version or capability) |
| leverage | meaning "use" | financial/physics contexts |
| utilize | meaning "use" | (almost always just say "use") |
| optimize | meaning "improve" | describing specific algorithmic optimization |
| streamline | meaning "improve" | describing specific workflow reduction |
| empower | meaning "allow" or "enable" | (almost never valid in technical writing) |
| elevate | meaning "improve" | (almost never valid in technical writing) |
| unlock | meaning "enable" | (almost never valid in technical writing) |
| harness | meaning "use" | (almost never valid in technical writing) |
| spearhead | meaning "lead" or "start" | (almost never valid) |
| synergy | used for anything | (almost never valid) |
| holistic | meaning "complete" | specific methodological contexts |
| comprehensive | used as generic praise | describing test coverage or documentation scope |
| intuitive | used as generic praise | backed by usability testing |
| scalable | used as generic praise | describing specific scaling properties |
| elegant | describing any solution | (subjective -- prefer specific qualities) |

---

## 4. Hedging Language (Medium Confidence)

Weakens claims without adding nuance. Make definitive or remove. Flag when
used to avoid commitment rather than express genuine uncertainty.

| Pattern | Slop when... | Valid when... |
|---|---|---|
| It seems like | hedging a known fact | expressing genuine uncertainty |
| It appears that | hedging a known fact | describing observed but unconfirmed behavior |
| might be able to | hedging a capability | genuine uncertainty about feasibility |
| could potentially | hedging anything | (almost always -- "could" or "potentially," not both) |
| may or may not | hedging anything | (almost always -- pick one) |
| to some extent | vague qualifier | (almost always vague) |
| in some cases | without specifying which | followed by specific cases |
| generally speaking | without specifics | followed by exceptions |
| for the most part | without specifics | followed by exceptions |
| arguably | without arguing | (almost always -- either argue or don't) |
| it can be said that | avoiding direct statement | (always remove -- just say it) |
| one might consider | avoiding recommendation | (always remove -- make the recommendation) |
| there is a possibility that | hedging known fact | genuine uncertainty with data backing |

---

## 5. Structural Slop (High Confidence)

Patterns in how text is organized, not just word choice.

### Sycophantic Openers

Remove entirely. Start with the actual content.

- "Great question!"
- "That's a great question."
- "Excellent question!"
- "That's an excellent point."
- "Good question!"
- "What a fantastic question."
- "I'd be happy to help!"
- "I'd be happy to help with that."
- "Absolutely!"
- "Of course!"
- "Sure thing!"
- "Great choice!"
- "Happy to assist!"

### Summary Openers

Remove or replace with the actual first sentence.

- "In summary, ..."
- "To summarize, ..."
- "In conclusion, ..."
- "To sum up, ..."
- "Overall, ..."
- "In a nutshell, ..."
- "Here's the bottom line: ..."
- "The key takeaway is ..."

### Rhetorical Transitions

Remove and let the content flow naturally.

- "Now, let's turn our attention to ..."
- "With that in mind, ..."
- "Building on that, ..."
- "Moving forward, ..."
- "Going forward, ..."
- "That said, ..."
- "With that context, ..."
- "Now that we've covered X, let's look at Y"
- "Let's break this down"
- "Let's unpack this"
- "Let's dive in"
- "Let's dive into"
- "Let's take a step back"

### False Comprehensiveness

Phrases that imply exhaustive coverage without delivering it.

- "There are several key aspects to consider"
- "This involves multiple factors"
- "There are many ways to approach this"
- "This is a multifaceted issue"
- "There's a lot to unpack here"

---

## 6. Formatting Slop (Medium Confidence)

Stylistic patterns that signal AI origin. Context matters.

### Emoji Overuse

- Emoji in technical documentation or code comments (always flag)
- Emoji in headings (almost always flag)
- Emoji used as bullet points (always flag)
- Exception: emoji in user-facing UI copy if the project style uses them

### Em Dash Overuse

- More than one em dash per paragraph (flag)
- Em dashes used instead of commas or parentheses (flag)
- Exception: em dashes are valid in some editorial styles -- check project
  conventions

### Exclamation Overuse

- More than one exclamation mark per document section (flag)
- Exclamation marks in technical documentation (always flag)
- Exception: error messages or warnings where emphasis is intentional

### Unnecessary Bold/Italic

- Bolding common words for emphasis in every paragraph (flag)
- Italic used for scare quotes or hedging (flag)
- Exception: bold for defined terms, italic for book titles or technical terms

---

## 7. Code Comment Slop (High Confidence)

Patterns specific to AI-generated code comments. These almost always add
noise rather than value.

### Restating Comments

Comments that say exactly what the code says. Remove them.

```
// Increment the counter
counter++;

// Check if user is authenticated
if (user.isAuthenticated) {

// Return the result
return result;

// Import dependencies
import { foo } from 'bar';

// Define the interface
interface User {
```

### Obvious Docstrings

Docstrings that restate the function signature without adding information.

```python
def get_user(user_id: int) -> User:
    """Get a user by their user ID.

    Args:
        user_id: The ID of the user.

    Returns:
        The user object.
    """
```

Flag when: the docstring adds nothing beyond what the signature already says.
Valid when: the docstring explains behavior, side effects, exceptions, or
non-obvious constraints.

### Section Divider Comments

```
// ============================================
// HELPER FUNCTIONS
// ============================================

# --- Configuration ---

/* *** Main Logic *** */
```

Flag when: the divider separates 2-3 functions that are obviously related.
Valid when: the file is long (200+ lines) and sections are genuinely distinct.

### Changelog Comments

```
// Added in v2.0
// TODO: Remove after migration (added 2024-01-15)
// HACK: Temporary fix for issue #123
```

Flag when: the comment describes history better tracked by git.
Valid when: the comment explains WHY a hack exists and WHEN to remove it
(the "HACK" example above is actually borderline valid).

### Removed Code Comments

```
// Previously used X approach, now using Y
// Old implementation:
// const result = oldMethod();
```

Always flag. Git history preserves this. Commented-out code is never the
right approach.
