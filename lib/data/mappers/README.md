# Mappers

Row → model and model → companion, one file per aggregate. Pure functions, no database
access, no decisions — if a mapper needs an `if` that is about the domain, the rule belongs
in a repository or in `core/utils/`.

They exist because `lib/models/` stays free of drift. Drift generates its own row classes
from the table definitions; these functions are the seam between the two, and they are the
reason the models can still be handed to the PDF renderer or serialised by Phase 3's sync
layer without dragging a database dependency along.

Orders and receipts take their lines as a second argument — `orderFromRows(row, lineRows)`
— because `PurchaseOrder.lines` is an embedded list in the model and a child table in the
schema. That asymmetry lives here and nowhere else.
