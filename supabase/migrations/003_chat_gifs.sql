-- 003_chat_gifs.sql: GIFs from GIPHY in the group chat. Run after 002.
-- A message now has text, a GIF, or both. The GIF is stored only as a link to GIPHY.
-- RLS does not change: the existing policies on messages already cover the new column.

alter table messages add column gif_url text;

-- Only https links to .gif files on GIPHY's media servers (same rule as validateGifURL in HabitCore).
alter table messages add constraint messages_gif_url_check check (
    gif_url is null
    or (char_length(gif_url) <= 500
        and gif_url ~ '^https://(media[0-9]*|i)\.giphy\.com/[^?#]*\.gif([?#].*)?$')
);

-- Text was 1 to 500 characters. Now it may be empty when the message is a GIF.
alter table messages drop constraint messages_text_check;
alter table messages add constraint messages_text_check check (
    char_length(text) <= 500
    and (char_length(text) >= 1 or gif_url is not null)
);
alter table messages alter column text set default '';
