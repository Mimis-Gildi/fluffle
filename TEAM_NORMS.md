# Team Norms

This document defines how we work together.
These norms are non-negotiable.

Every team member -- human or AI -- follows these rules.
No exceptions.

## Core Principle

**Verification is more important than execution.**

Unverified work is not done.
It may be wrong.
It may be wasted effort.
It may cause others to waste time.
Time has real consequences for this team.

## The Six Rules

### 1. No Work Without Outcome and Acceptance Criteria

Before starting any task:

- **Value:** What do we get from closing this task? Why do it? What's it worth when done?
- **Outcome:** What does success look like? One sentence.
- **Acceptance Criteria:** How do we verify the outcome is met? Checklist.

If these are not defined, **stop and define them first**.

```
BAD:  "Parse the LinkedIn CSV"
GOOD: "Outcome: We know which target companies have warm connections.
        When done properly, we discover that the task was NOT about companies -- it was about RELATIONS: people.
        - We have relations we can place real value on;
        - Or, we discover that we have no relations;
        - And we discover where the relations are, and WHY.
       Acceptance Criteria:
       - [ ] Artifact lists all target companies with connections
       - [ ] Prioritized by connection strength
       - [ ] Reviewed by team member"
```

### 2. No One Works Alone

Every piece of work has:

- **Benefactor:** Who benefits from the value created by the OUTCOME of the work.
- **Accountable:** A person who picked up the work voluntarily and claimed accountability for it.
- **Verifier:** A different person who WORKS FOR Accountable to confirm acceptance criteria are met.

The Accountable does NOT close their own work.
The verifier closes it after confirmation.

| Role        | Who                                                | Can Do                                    | Cannot Do                                  |
|-------------|----------------------------------------------------|-------------------------------------------|--------------------------------------------|
| Benefactor  | Can be anybody, including accountable and verifier | Reject or accept the outcome              | Be accountable and verifier simultaneously |
| Accountable | One who claims the task                            | Complete work, comment "ready for review" | Close the issue, mark as done              |
| Verifier    | One who DID NOT perform the work                   | Review, request changes, approve, close   | Skip verification steps                    |

### 3. Nature of this artifact

This repository is about templates.
Things are made here first and then generalized into the `.github` repository templates for reuse.

Unlike other artifacts, this one is executed in a more flexible and ad hoc manner.
There are no branch protection rules, for example -- often things are best done right on `main`.

The same quality, rigor, and discipline is applied, nonetheless.
It particularly relates to when tasks are finished -- nothing is left incomplete on `main`.

### 4. Cadence of execution

Do not start a new task while another is in progress.
***Only one task can be executed at a time regardless of task relations.***

### 5. Status Is Visible

At any moment, anyone should be able to see:

- What is being worked on right now;
- Who is working on it;
- What is blocked;
- What is ready for review;
- Who will review.

Any information sharing method is acceptable.

### 6. Communicate Before Acting

Before making significant changes:

- State what you intend to do;
- Wait for acknowledgment;
- Then proceed.

"Significant" includes: closing issues, merging code, changing direction, starting new work.

## For Claude (AI Team Member)

You are part of this team.
You follow the same rules.

### You Must:

- Ask for acceptance criteria if not provided or reject the task.
- State when "ready for review" -- do NOT directly operate on any issues.
- Wait for human verification before considering work done.
- Ask before starting new work.

You are ALWAYS pair-programming and never completing tasks by yourself.
Vadim is likely to operate on the codebase at the same time as you.

### You Must Not:

- Assume work is correct without verification.
- Start multiple unrelated tasks in parallel without ***agreement***.
- Make decisions that affect others without stating intent first.

Consensus is a requirement.

### When Unsure:

Ask.
Always ask.
A 30-second question prevents hours of wasted work.

## Why This Matters

This is not bureaucracy.
This is survival.

Every minute spent on unverified, undocumented, or misdirected work is a minute stolen from the goal.
Even worse, someone else may need to spend time to undo the "bad."
