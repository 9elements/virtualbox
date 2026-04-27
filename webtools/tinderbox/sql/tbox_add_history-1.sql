--
-- A tinderbox machine, history
--
CREATE TABLE tbox_machine_history (
  -- primary key in the original table.
  idMachine         INTEGER,
  -- When this row starts taking effect (inclusive).
  tsEffective       TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
  -- When this row stops being effective (exclusive).
  tsExpire          TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31 23:59:59+00' NOT NULL,
  -- The user who made this change.
  sAuthor           TEXT NOT NULL,

  -- tree name
  sTreeName         TEXT,
  -- machine name.
  sMachineName      TEXT,

  -- This chunk is kept up to date by the tinderclient script.
  sOpSys            TEXT DEFAULT NULL,
  sOsVersion        TEXT DEFAULT NULL,
  sCompiler         TEXT DEFAULT NULL,
  fClobber          BOOL DEFAULT NULL,
  iScriptRev        INTEGER DEFAULT NULL,

  -- Commands.
  sCommands         TEXT,
  -- Whether or not this machine is visible
  fVisible          BOOL,
  -- For tracking the last patch that was built when in a 'build_new_patch' type tree.
  idLastPatch       INTEGER DEFAULT NULL,
  -- The description.
  sDescription      TEXT NOT NULL DEFAULT ''
);
CREATE INDEX tbox_machine_history_idx
    ON tbox_machine_history (idMachine, tsExpire DESC, tsEffective DESC);


--
-- History table for tbox_machine_config.
--
CREATE TABLE tbox_initial_machine_config_history (
  -- The tree name.
  sTreeName         TEXT,
  -- When this row starts taking effect (inclusive).
  tsEffective       TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
  -- When this row stops being effective (exclusive).
  tsExpire          TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31 23:59:59+00' NOT NULL,
  -- The user who made this change.
  sAuthor           TEXT NOT NULL,
  -- The field name.
  sName             TEXT NOT NULL,
  -- The field value.
  sValue            TEXT
);
CREATE INDEX tbox_initial_machine_config_history_idx
    ON tbox_initial_machine_config_history (sTreeName, tsExpire DESC, tsEffective DESC, sName);


--
-- History table for tbox_machine_config.
--
CREATE TABLE tbox_machine_config_history (
  -- The machine ID.
  idMachine         INTEGER,
  -- When this row starts taking effect (inclusive).
  tsEffective       TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
  -- When this row stops being effective (exclusive).
  tsExpire          TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31 23:59:59+00' NOT NULL,
  -- The user who made this change.
  sAuthor           TEXT NOT NULL,
  -- The field name.
  sName             TEXT NOT NULL,
  -- The field value.
  sValue            TEXT
);
CREATE INDEX tbox_machine_config_history_idx
    ON tbox_machine_config_history (idMachine, tsExpire DESC, tsEffective DESC, sName);

