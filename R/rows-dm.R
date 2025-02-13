#' Modifying rows for multiple tables
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' These functions provide a framework for updating data in existing tables.
#' Unlike [compute()], [copy_to()] or [copy_dm_to()], no new tables are created
#' on the database.
#' All operations expect that both existing and new data are presented
#' in two compatible [dm] objects on the same data source.
#'
#' The functions make sure that the tables in the target dm
#' are processed in topological order so that parent (dimension)
#' tables receive insertions before child (fact) tables.
#'
#' These operations, in contrast to all other operations,
#' may lead to irreversible changes to the underlying database.
#' Therefore, in-place operation must be requested explicitly with `in_place = TRUE`.
#' By default, an informative message is given.
#'
#' @inheritParams rlang::args_dots_empty
#' @inheritParams dplyr::rows_insert
#' @inheritParams dm_examine_constraints
#' @param x Target `dm` object.
#' @param y `dm` object with new data.
#'
#' @return A dm object of the same [dm_ptype()] as `x`.
#'   If `in_place = TRUE`, the underlying data is updated as a side effect,
#'   and `x` is returned, invisibly.
#'
#' @name rows-dm
#' @examplesIf rlang::is_installed("RSQLite") && rlang::is_installed("nycflights13")
#' # Establish database connection:
#' sqlite <- DBI::dbConnect(RSQLite::SQLite())
#'
#' # Entire dataset with all dimension tables populated
#' # with flights and weather data truncated:
#' flights_init <-
#'   dm_nycflights13() %>%
#'   dm_zoom_to(flights) %>%
#'   filter(FALSE) %>%
#'   dm_update_zoomed() %>%
#'   dm_zoom_to(weather) %>%
#'   filter(FALSE) %>%
#'   dm_update_zoomed()
#'
#' # Target database:
#' flights_sqlite <- copy_dm_to(sqlite, flights_init, temporary = FALSE)
#' print(dm_nrow(flights_sqlite))
#'
#' # First update:
#' flights_jan <-
#'   dm_nycflights13() %>%
#'   dm_select_tbl(flights, weather) %>%
#'   dm_zoom_to(flights) %>%
#'   filter(month == 1) %>%
#'   dm_update_zoomed() %>%
#'   dm_zoom_to(weather) %>%
#'   filter(month == 1) %>%
#'   dm_update_zoomed()
#' print(dm_nrow(flights_jan))
#'
#' # Copy to temporary tables on the target database:
#' flights_jan_sqlite <- copy_dm_to(sqlite, flights_jan)
#'
#' # Dry run by default:
#' dm_rows_append(flights_sqlite, flights_jan_sqlite)
#' print(dm_nrow(flights_sqlite))
#'
#' # Explicitly request persistence:
#' dm_rows_append(flights_sqlite, flights_jan_sqlite, in_place = TRUE)
#' print(dm_nrow(flights_sqlite))
#'
#' # Second update:
#' flights_feb <-
#'   dm_nycflights13() %>%
#'   dm_select_tbl(flights, weather) %>%
#'   dm_zoom_to(flights) %>%
#'   filter(month == 2) %>%
#'   dm_update_zoomed() %>%
#'   dm_zoom_to(weather) %>%
#'   filter(month == 2) %>%
#'   dm_update_zoomed()
#'
#' # Copy to temporary tables on the target database:
#' flights_feb_sqlite <- copy_dm_to(sqlite, flights_feb)
#'
#' # Explicit dry run:
#' flights_new <- dm_rows_append(
#'   flights_sqlite,
#'   flights_feb_sqlite,
#'   in_place = FALSE
#' )
#' print(dm_nrow(flights_new))
#' print(dm_nrow(flights_sqlite))
#'
#' # Check for consistency before applying:
#' flights_new %>%
#'   dm_examine_constraints()
#'
#' # Apply:
#' dm_rows_append(flights_sqlite, flights_feb_sqlite, in_place = TRUE)
#' print(dm_nrow(flights_sqlite))
#'
#' DBI::dbDisconnect(sqlite)
NULL


#' dm_rows_insert
#'
#' `dm_rows_insert()` adds new records via [rows_insert()] with `conflict = "ignore"`.
#' Duplicate records will be silently discarded.
#' This operation requires primary keys on all tables, use `dm_rows_append()`
#' to insert unconditionally.
#' @rdname rows-dm
#' @aliases dm_rows_...
#' @export
dm_rows_insert <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "insert", top_down = TRUE, in_place, require_keys = TRUE, progress = progress)
}

#' dm_rows_append
#'
#' `dm_rows_append()` adds new records via [rows_append()].
#' The primary keys must differ from existing records.
#' This must be ensured by the caller and might be checked by the underlying database.
#' Use `in_place = FALSE` and apply [dm_examine_constraints()] to check beforehand.
#' @rdname rows-dm
#' @export
dm_rows_append <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "append", top_down = TRUE, in_place, require_keys = FALSE, progress = progress)
}

#' dm_rows_update
#'
#' `dm_rows_update()` updates existing records via [rows_update()].
#' Primary keys must match for all records to be updated.
#'
#' @rdname rows-dm
#' @export
dm_rows_update <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "update", top_down = TRUE, in_place, require_keys = TRUE, progress = progress)
}

#' dm_rows_patch
#'
#' `dm_rows_patch()` updates missing values in existing records
#' via [rows_patch()].
#' Primary keys must match for all records to be patched.
#'
#' @rdname rows-dm
#' @export
dm_rows_patch <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "patch", top_down = TRUE, in_place, require_keys = TRUE, progress = progress)
}

#' dm_rows_upsert
#'
#' `dm_rows_upsert()` updates existing records and adds new records,
#' based on the primary key, via [rows_upsert()].
#'
#' @rdname rows-dm
#' @export
dm_rows_upsert <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "upsert", top_down = TRUE, in_place, require_keys = TRUE, progress = progress)
}

#' dm_rows_delete
#'
#' `dm_rows_delete()` removes matching records via [rows_delete()],
#' based on the primary key.
#' The order in which the tables are processed is reversed.
#'
#' @rdname rows-dm
#' @export
dm_rows_delete <- function(x, y, ..., in_place = NULL, progress = NA) {
  check_dots_empty()

  dm_rows(x, y, "delete", top_down = FALSE, in_place, require_keys = TRUE, progress = progress)
}

dm_rows <- function(x, y, operation_name, top_down, in_place, require_keys, progress = NA) {
  dm_rows_check(x, y)

  if (is_null(in_place)) {
    inform("Result is returned as a dm object with lazy tables. Use `in_place = FALSE` to mute this message, or `in_place = TRUE` to write to the underlying tables.")
    in_place <- FALSE
  }

  dm_rows_run(x, y, operation_name, top_down, in_place, require_keys, progress = progress)
}

dm_rows_check <- function(x, y) {
  check_not_zoomed(x)
  check_not_zoomed(y)

  check_same_src(x, y)
  check_tables_superset(x, y)
  tables <- dm_get_tables_impl(y)
  walk2(dm_get_tables_impl(x)[names(tables)], tables, check_columns_superset)
  check_keys_compatible(x, y)
}

check_same_src <- function(x, y) {
  tables <- c(dm_get_tables_impl(x), dm_get_tables_impl(y))
  if (!all_same_source(tables)) {
    abort_not_same_src()
  }
}

check_tables_superset <- function(x, y) {
  tables_missing <- setdiff(src_tbls_impl(y), src_tbls_impl(x))
  if (has_length(tables_missing)) {
    abort_tables_missing(tables_missing)
  }
}

check_columns_superset <- function(target_tbl, tbl) {
  columns_missing <- setdiff(colnames(tbl), colnames(target_tbl))
  if (has_length(columns_missing)) {
    abort_columns_missing(columns_missing)
  }
}

check_keys_compatible <- function(x, y) {
  # FIXME
}

get_dm_rows_op <- function(operation_name) {
  switch(operation_name,
    "insert"   = list(fun = do_rows_insert, pb_label = "inserting rows"),
    "append"   = list(fun = do_rows_append, pb_label = "appending rows"),
    "update"   = list(fun = do_rows_update, pb_label = "updating rows"),
    "patch"    = list(fun = do_rows_patch, pb_label = "patching rows"),
    "upsert"   = list(fun = do_rows_upsert, pb_label = "upserting rows"),
    "delete"   = list(fun = do_rows_delete, pb_label = "deleting rows"),
    "truncate" = list(fun = rows_truncate_, pb_label = "truncating rows")
  )
}

do_rows_insert <- function(x, y, by = NULL, ..., autoinc_col = NULL) {
  stopifnot(is.null(autoinc_col))
  rows_insert(x, y, by = by, ..., conflict = "ignore")
}

do_rows_append <- function(x, y, by = NULL, ..., in_place = FALSE, autoinc_col = NULL) {
  if (is.null(autoinc_col)) {
    return(rows_append(x, y, ..., in_place = in_place))
  }

  # Assuming in-place append operation on dbplyr data source
  stopifnot(inherits(x, "tbl_dbi"))
  stopifnot(in_place)

  # FIXME: optimize if unique key exists
  returning <- sym(autoinc_col)
  key_values <-
    y %>%
    select(!!returning) %>%
    collect() %>%
    pull()

  if (anyDuplicated(key_values)) {
    abort(paste0("Duplicate values for autoincrement primary key ", autoinc_col, "."))
  }

  autoinc_col_new <- paste0(autoinc_col, "_new")
  if (length(key_values) == 0) {
    return(tibble(
      !!sym(autoinc_col) := integer(),
      !!sym(autoinc_col_new) := integer(),
    ))
  }

  source_rows <- map(key_values, ~ select(filter(y, !!returning == !!.x), -!!returning))

  con <- dbplyr::remote_con(x)
  # FIXME can be removed after depending on dbplyr >= 2.4.0
  append_args <- rlang::fn_fmls_names(dbplyr::sql_query_append)
  old_interface <- identical(append_args, c("con", "x_name", "y", "...", "returning_cols"))
  if (old_interface) {
    target_name <- remote_name_qual(x)
    insert_queries <- map(source_rows, ~ dbplyr::sql_query_append(
      con,
      target_name,
      .x,
      returning_cols = autoinc_col
    ))
  } else {
    # FIXME: dbplyr::remote_table() private in dbplyr 2.3.3, public in dbplyr 2.4.0
    dbplyr_ns <- asNamespace("dbplyr")
    remote_table <- mget("remote_table", dbplyr_ns, mode = "function", ifnotfound = list(NULL))[[1]]

    insert_queries <- map(source_rows, ~ dbplyr::sql_query_append(
      con,
      remote_table(x),
      from = dbplyr::sql_render(.x, con),
      insert_cols = colnames(.x),
      returning_cols = autoinc_col
    ))
  }

  autoinc_col_orig <- paste0(autoinc_col, "_orig")

  insert_sql <- sql(unlist(insert_queries))

  # Run INSERT INTO queries, side effect!
  # Must run queries individually, e.g. on Postgres:
  # > WITH clause containing a data-modifying statement must be at the top level
  insert_res <- map(insert_queries, ~ DBI::dbGetQuery(con, .x))

  out <- tibble(
    bind_rows(!!!insert_res),
    !!sym(autoinc_col_orig) := !!key_values
  )

  set_names(out[2:1], c(autoinc_col, autoinc_col_new))
}

do_rows_update <- function(x, y, by = NULL, ..., autoinc_col = NULL) {
  stopifnot(is.null(autoinc_col))
  rows_update(x, y, by = by, ..., unmatched = "ignore")
}

do_rows_patch <- function(x, y, by = NULL, ..., autoinc_col = NULL) {
  stopifnot(is.null(autoinc_col))
  rows_patch(x, y, by = by, ..., unmatched = "ignore")
}

do_rows_upsert <- function(x, y, by = NULL, ..., autoinc_col = NULL) {
  stopifnot(is.null(autoinc_col))
  rows_upsert(x, y, by = by, ...)
}

do_rows_delete <- function(x, y, by = NULL, ..., autoinc_col = NULL) {
  stopifnot(is.null(autoinc_col))
  rows_delete(x, y, by = by, ..., unmatched = "ignore")
}

dm_rows_run <- function(x, y, rows_op_name, top_down, in_place, require_keys, progress = NA) {
  # topologically sort tables
  graph <- create_graph_from_dm(x, directed = TRUE)
  topo <- igraph::topo_sort(graph, mode = if (top_down) "in" else "out")
  tables <- intersect(names(topo), src_tbls_impl(y))

  # Use tables and keys
  target_tbls <- dm_get_tables_impl(x)[tables]
  tbls <- dm_get_tables_impl(y)[tables]

  if (require_keys) {
    all_pks <- dm_get_all_pks(x)
    if (!(all(tables %in% all_pks$table))) {
      abort(glue("`dm_rows_{rows_op_name}()` requires the 'dm' object to have primary keys for all target tables."))
    }
    keys <- all_pks$pk_col[match(tables, all_pks$table)]
  } else {
    keys <- rep_along(tables, list(NULL))
  }

  # FIXME: Use keyholder?

  rows_op <- get_dm_rows_op(rows_op_name)
  ticker <- new_ticker(rows_op$pb_label, length(tables), progress)
  op_ticker <- ticker(rows_op$fun)

  if (!in_place) {
    op_results <- target_tbls
  }

  # run operation(target_tbl, tbl, in_place = in_place) for each table
  for (i in seq_along(tables)) {
    table <- tables[[i]]
    tbl <- tbls[[i]]

    # FIXME: implement for in_place = FALSE
    if (in_place && (rows_op_name == "append")) {
      autoinc_col <- get_autoinc_col(x, table, colnames(tbl))
    } else {
      autoinc_col <- NULL
    }

    # Returns tibble if autoinc_col is set, `target_tbl` otherwise
    res <- op_ticker(
      target_tbls[[i]],
      tbl,
      by = keys[[i]],
      in_place = in_place,
      autoinc_col = autoinc_col
    )

    if (!is.null(autoinc_col)) {
      tbls <- align_autoinc_fks(tbls, x, table, res)
    } else if (!in_place) {
      op_results[[i]] <- res
    }
  }

  if (in_place) {
    invisible(x)
  } else {
    x %>%
      dm_patch_tbl(!!!op_results)
  }
}

dm_patch_tbl <- function(dm, ...) {
  check_not_zoomed(dm)

  new_tables <- list2(...)

  # FIXME: Better error message for unknown tables

  def <- dm_get_def(dm)
  idx <- match(names(new_tables), def$table)
  def[idx, "data"] <- list(unname(new_tables))
  new_dm3(def)
}

get_autoinc_col <- function(x, table, cols) {
  my_pk <- dm_get_all_pks_impl(x, table)
  stopifnot(nrow(my_pk) %in% 0:1)

  if (!isTRUE(my_pk$autoincrement)) {
    return(NULL)
  }

  pk_col <- get_key_cols(my_pk$pk_col[[1]])
  if (!(pk_col %in% cols)) {
    return(NULL)
  }

  pk_col
}

align_autoinc_fks <- function(tbls, target_dm, table, returning_rows) {
  fks <- dm_get_all_fks_impl(target_dm, table)
  fks_target <- fks[fks$child_table %in% names(tbls), ]

  all_target_tables <- dm_get_tables(target_dm)[fks_target$child_table]
  all_target_cols <- unique(unlist(map(all_target_tables, colnames)))

  pk_col <- names(returning_rows)[[1]]
  new_pk_col <- derive_temp_column_name(all_target_cols, pk_col)
  names(returning_rows)[[2]] <- new_pk_col

  # Structure: <pk_col>, <new_pk_col>
  align_tbl <- dbplyr::copy_inline(dm_get_con(target_dm), returning_rows)

  for (i in seq_along(fks_target$child_table)) {
    child_table <- fks_target$child_table[[i]]
    child_fk_col <- get_key_cols(fks_target$child_fk_cols[[i]])
    tbl <- tbls[[child_table]]

    if (child_fk_col %in% colnames(tbl)) {
      tbls[[child_table]] <-
        tbl %>%
        left_join(align_tbl, by = vec_c(!!child_fk_col := pk_col)) %>%
        select(-!!sym(child_fk_col), !!sym(child_fk_col) := sym(new_pk_col)) %>%
        select(!!!colnames(tbl))
    }
  }

  tbls
}

derive_temp_column_name <- function(tbl_names, base, suffix = "_new") {
  new_name <- paste0(base, suffix)
  tbl_names <- colnames(tbl)

  repeat {
    if (!(new_name %in% tbl_names)) {
      return(new_name)
    }
    new_name <- paste0(new_name, "_")
  }
}

# Errors ------------------------------------------------------------------

abort_columns_missing <- function(...) {
  # FIXME
  abort("")
}

error_txt_columns_missing <- function(...) {
  # FIXME
}

abort_tables_missing <- function(...) {
  # FIXME
  abort("")
}

error_txt_tables_missing <- function(...) {
  # FIXME
}
