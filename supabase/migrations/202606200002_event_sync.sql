create unique index if not exists learning_events_sync_unique
  on public.learning_events(user_id,event_type,item_id,created_at);
