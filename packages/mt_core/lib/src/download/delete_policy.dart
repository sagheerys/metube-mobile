/// What happens after a pull (`05-DATA-SCHEMA.md` §2.5):
/// - [autoDelete] for Lite: delete from the server after pulling, so the
/// server cleans itself.
/// - [keepOnServer] for Super: it stays on the server, and deletion is
/// manual only.
enum DeletePolicy { autoDelete, keepOnServer }
