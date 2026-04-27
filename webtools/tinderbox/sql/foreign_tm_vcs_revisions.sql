-- ASSUMES that we've already got testmanager_users

CREATE FOREIGN TABLE testmanager_vcs_revisions (
    --- The version control tree name.
    sRepository         TEXT        NOT NULL,
    --- The version control tree revision number.
    iRevision           INTEGER     NOT NULL,
    --- When the revision was created (committed).
    tsCreated           TIMESTAMP WITH TIME ZONE  NOT NULL,
    --- The name of the committer.
    -- @note Not to be confused with uidAuthor and test manager users.
    sAuthor             TEXT,
    --- The commit message.
    sMessage            TEXT
)
    SERVER testmanager
    OPTIONS (schema_name 'public', table_name 'vcsrevisions', updatable 'false');

