# Capability: decisions

A decision is the durable part of a document. Keeping one is an action, undoing it
is one action, and refusing one is not deleting it.

## Requirements

### Requirement: keeping is one action
Keeping a proposal SHALL apply the branch and its geometry as a single action, and
undoing it SHALL revert exactly that.

#### Scenario: undo after a keep
- **GIVEN** a proposal was kept
- **WHEN** the person undoes
- **THEN** the document returns to its state before the keep

### Requirement: a set-aside direction keeps its memory
A direction that was set aside SHALL remain in the document, SHALL say it was set
aside, and SHALL be reopenable by a named accessibility action as well as by a
double-click.

#### Scenario: reopening
- **WHEN** the person reopens a set-aside direction
- **THEN** it returns with the geometry it had

### Requirement: rejection is not deletion
Nothing in the application SHALL delete a direction because it was rejected, and
a rejected direction SHALL remain listable.

### Requirement: a reopened document is the origin of what can be replayed
A document reopened from disk SHALL have no replay origin earlier than its
persisted state, and a preview of a recorded action SHALL be computed from that
state forward.

This is a contract, not an implementation note. A session that reopens a file has
no memory of what came before the entries the file already contains, and saying
otherwise would mean inventing a past the product never saw. Where the file's own
history is older than anything this session recorded, a preview of the oldest
entry is the present, and the differences shown are empty rather than fabricated.

#### Scenario: a preview after reopening
- **GIVEN** a document was saved, quit and reopened
- **WHEN** the person previews its oldest recorded action
- **THEN** the preview is the document as reopened
- **AND** no state before that is claimed

#### Scenario: a preview within one session
- **GIVEN** two actions were recorded in this session
- **WHEN** the person previews the first of them
- **THEN** the preview is the document as it was before that action

### Requirement: a local decision is local
A decision made on the machine SHALL NOT be reported as synchronised, and no
network call SHALL be implied by it.
