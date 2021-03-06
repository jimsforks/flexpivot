
#' Flextable format for `pivot_table`
#'
#' @param pivot A \code{\link{pivot_table}} object.
#' @param background Background color for the header and column(s) containing row(s).
#' @param color Text color for the header and column(s) containing row(s).
#' @param border Border color (applies to all table).
#' @param font_size Font size (applies to all table).
#' @param font_name Font name (applies to all table).
#' @param labels Custom labels for statistics, see \code{\link{pivot_labels}}.
#' @param formatter Function to format content, see \code{\link{pivot_formatter}}.
#' @param zebra_style Add zebra theme to table.
#' @param zebra_color Color to use for zebra theme.
#' @param drop_stats Drop the stats column, can be useful if have only one stat to show.
#' @param keep_data Keep data as attribute, this can
#'  be useful to retrieve the data from which the table was formatted.
#'
#' @return a `flextable` object.
#' @export
#'
#' @importFrom flextable flextable theme_zebra merge_v bg color
#'  bold fontsize font padding width border set_header_df merge_h align
#' @importFrom officer fp_border
#' @importFrom data.table copy .SD first := setnames setattr uniqueN
#'
#' @example examples/pivot_format.R
pivot_format <- function(pivot,
                         background = "#81A1C1",
                         color = "#FFFFFF",
                         border = "#FFFFFF",
                         font_size = 14,
                         font_name = NULL,
                         labels = pivot_labels(),
                         formatter = pivot_formatter(),
                         zebra_style = c("classic", "stats", "none"),
                         zebra_color = "#ECEFF4",
                         drop_stats = FALSE,
                         keep_data = TRUE) {
  zebra_style <- match.arg(zebra_style)
  if (!inherits(pivot, "pivot_table"))
    stop("pivot_format: 'pivot' must be a 'pivot_table' object", call. = FALSE)
  pt <- copy(pivot)
  rows <- attr(pt, "rows", exact = TRUE)
  cols <- attr(pt, "cols", exact = TRUE)
  cols_values <- attr(pt, "cols_values", exact = TRUE)
  if (!is.null(cols)) {

    # Apply formatter
    cols_vars <- setdiff(names(pt), c(rows, "stats"))
    pt[, (cols_vars) := lapply(.SD, as.character), .SDcols = cols_vars]
    pt[stats == "n", (cols_vars) := lapply(.SD, function(x) {
      formatter$n(as.numeric(x))
    }), .SDcols = cols_vars]
    pt[stats == "p", (cols_vars) := lapply(.SD, function(x) {
      formatter$p(as.numeric(x))
    }), .SDcols = cols_vars]
    pt[stats == "p_col", (cols_vars) := lapply(.SD, function(x) {
      formatter$p_col(as.numeric(x))
    }), .SDcols = cols_vars]
    pt[stats == "p_row", (cols_vars) := lapply(.SD, function(x) {
      formatter$p_row(as.numeric(x))
    }), .SDcols = cols_vars]

    # Apply labels
    pt[stats == "n", stats := labels$n]
    pt[stats == "p", stats := labels$p]
    pt[stats == "p_col", stats := labels$p_col]
    pt[stats == "p_row", stats := labels$p_row]
    setnames(pt, "stats", labels$stats)
    setattr(pt, "stat", labels$stats)
  } else {

    # Apply formatter
    cols_vars <- setdiff(names(pt), rows)
    pt[, (cols_vars) := lapply(.SD, as.character), .SDcols = cols_vars]
    if (hasName(pt, "n")) {
      pt[, n := formatter$n(as.numeric(n))]
    }
    if (hasName(pt, "p")) {
      pt[, p := formatter$p(as.numeric(p))]
    }

    # Apply labels
    setnames(
      x = pt,
      old = c("n", "p", "p_row", "p_col"),
      new = c(labels$n, labels$p, labels$p_col, labels$p_row),
      skip_absent = TRUE
    )
  }

  if (!is.null(labels$rows)) {
    setnames(
      x = pt,
      old = rows,
      new = labels$rows,
      skip_absent = TRUE
    )
    setattr(pt, "rows", labels$rows)
  }

  if (isTRUE(drop_stats)) {
    col_keys <- setdiff(names(pt), labels$stats)
  } else {
    col_keys <- names(pt)
  }
  ft <- flextable(pt, col_keys = col_keys)

  if (!identical(zebra_style, "none")) {
    if (is.null(cols)) {
      ft <- theme_zebra(ft, odd_body = zebra_color)
    } else {
      if (identical(zebra_style, "stats")) {
        ft <- bg(ft, i = ((seq_len(nrow(pt)) - 1) %/% uniqueN(pt[[labels$stats]])) %% 2 == 0, bg = zebra_color)
      } else {
        ft <- theme_zebra(ft, odd_body = zebra_color)
      }
    }
  }

  ft <- merge_v(ft, part = "body", j = seq_along(rows))
  ft <- bg(ft, j = seq_along(rows), bg = background, part = "body")
  ft <- color(ft, j = seq_along(rows), color = color, part = "body")
  ft <- bold(ft, j = seq_along(rows))

  if (!is.null(cols)) {
    ft <- border(
      ft, i = which(pt[[labels$stats]] == pt[[labels$stats]][1]),
      border.top = fp_border(color = "#D8DEE9", width = 2), part = "body"
    )
  }

  if (is.null(cols)) {
    ft <- bg(ft, bg = background, part = "header")
    ft <- color(ft, color = color, part = "header")
  } else {
    if (identical(length(cols), 1L)) {
      typology_what <- rep("", length(col_keys))
      if (!is.null(labels$cols)) {
        label_col <- labels$cols[1]
      } else {
        label_col <- cols
      }
      typology_what[col_keys %in% cols_values[[cols]]] <- label_col
      typology <- data.frame(
        col_keys = col_keys,
        what = typology_what,
        measure = col_keys,
        stringsAsFactors = FALSE
      )
      ft <- set_header_df(ft, mapping = typology, key = "col_keys")
      ft <- merge_h(ft, part = "header")
      ft <- align(ft, i = 1, align = "center", part = "header")
      ft <- align(ft, i = 2, align = "right", part = "header")
      ft <- bg(ft, i = 1, j = which(col_keys %in% cols_values[[cols]]), bg = background, part = "header")
      ft <- bg(ft, i = 2, bg = background, part = "header")
      ft <- color(ft, color = color, part = "header")
    } else {
      ft <- bg(ft, bg = background, part = "header")
      ft <- color(ft, color = color, part = "header")
    }
  }
  ft <- bold(ft, part = "header")
  ft <- fontsize(x = ft, size = font_size, part = "all")
  if (!is.null(font_name)) {
    ft <- font(x = ft, fontname = font_name, part = "all")
  }
  ft <- padding(x = ft, padding = 10, part = "all")
  ft <- width(x = ft, width = 1.5)
  if (!is.null(border))
    ft <- border(ft, border = fp_border(color = "#FFFFFF"), part = "all")
  setattr(ft, "class", c(class(ft), "flexpivot"))
  if (isTRUE(keep_data)) {
    setattr(ft, "data", pt)
  }
  return(ft)
}





#' Labels for \code{pivot_format}
#'
#' @param stats Name of statistics column.
#' @param n Count.
#' @param p Percentage.
#' @param p_col Column perc.
#' @param p_row Row perc.
#' @param rows,cols Labels for variables use as rows/cols.
#'
#' @return a \code{list} that can be use in \code{\link{pivot_format}}.
#' @export
#'
#' @example examples/pivot_labels.R
pivot_labels <- function(stats = "Statistic",
                         n = "N",
                         p = "%",
                         p_col = "Col %",
                         p_row = "Row %",
                         rows = NULL,
                         cols = NULL) {
  list(
    stats = stats,
    n = n,
    p = p,
    p_col = p_col,
    p_row = p_row,
    rows = rows,
    cols = cols
  )
}





#' Formatters for \code{pivot_format}
#'
#' @param n Function, applied to n.
#' @param p Function, applied to p.
#' @param p_col Function, applied to p_col.
#' @param p_row Function, applied to p_row.
#'
#' @return a \code{list} of \code{function}s that can be use in \code{\link{pivot_format}}.
#' @export
#'
#' @example examples/pivot_formatter.R
pivot_formatter <- function(n = round,
                            p = function(x) {
                              paste0(round(x, 1), "%")
                            },
                            p_col = function(x) {
                              paste0(round(x, 1), "%")
                            },
                            p_row = function(x) {
                              paste0(round(x, 1), "%")
                            }) {
  list(
    n = n,
    p = p,
    p_col = p_col,
    p_row = p_row
  )
}




