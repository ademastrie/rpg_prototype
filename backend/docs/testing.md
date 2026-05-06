# Backend Testing Notes

Static-review scenarios for inventory instances:

- Add `slime_gel` twice through `POST /characters/{character_id}/inventory/items`; the existing `slime_gel` inventory entry should remain one row and its `quantity` should increase up to `max_stack`.
- Add `training_sword` twice through `POST /characters/{character_id}/inventory/items`; the response should include two separate inventory entries with different `inventory_entry_id` values and `quantity` set to `1`.
- Equip one `training_sword` through `PUT /characters/{character_id}/equipment` using its `inventory_entry_id`; the other `training_sword` entry should remain in inventory and should not be marked equipped.
- Add another `training_sword` while one is equipped; the new sword should create another separate inventory entry and the equipped sword should remain equipped.
