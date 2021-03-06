#lang scribble/manual

@(require (for-label racket racket/date simple-xlsx))

@(require scribble/example)

@(define example-eval (make-base-eval))
@(example-eval '(require simple-xlsx racket/date))

@title{Simple-Xlsx: Open Xml Spreadsheet(.xlsx) Reader and Writer}

@author+email["Chen Xiao" "chenxiao770117@gmail.com"]

@defmodule[simple-xlsx]

The @tt{simple-xlsx} package allows you to read and write spreadsheets in the @tt{.xlsx} file format
used by Microsoft Excel and LibreOffice. This an open XML file format.

@table-of-contents[]

@section[#:tag "install"]{Install}

@codeblock{raco pkg install simple-xlsx}

@section{Read}

Functions for reading from a @filepath{.xlsx} file.

You can get a specific cell's value or loop for the whole sheet's rows.

There is also a complete read and write example 
@link["https://github.com/simmone/racket-simple-xlsx/blob/master/simple-xlsx/example/example.rkt"]{included
in the GitHub source}.

@defproc[(with-input-from-xlsx-file
              [xlsx_file_path path-string?]
              [user-proc (-> (is-a?/c read-xlsx%) void?)]
              )
            void?]{

Loads a @filepath{.xlsx} file and calls @racket[_user-proc] with the resulting @racket[read-xlsx%]
object as its only argument.

To make changes to the file, convert the @racket[read-xlsx%] object to @racket[xlsx%] using
@racket[from-read-to-write-xlsx].

}

@defproc[(load-sheet
           [sheet_name string?]
           [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
           )
           void?]{
  Load a sheet specified by its sheet name.
  
  This must be called before attempting to read any cell values.
}

@defproc[(get-sheet-names
            [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
            )
            (listof string?)]{
  Returns a list of sheet names.
}

@defproc[(get-cell-value
            [cell_axis string?]
            [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
            )
            (or/c string? number?)]{

Returns the value of a specific cell. Numeric values are returned as numbers, except when stored in
cells with “Text” format type. The @racket[_cell-axis] should be in the “A1” reference style.

  Example:

  @racketblock[
  (with-input-from-xlsx-file "workbook.xlsx"
    (lambda (xlsx)
      (load-sheet "Sheet1" xlsx)
      (get-cell-value "C12" xlsx)))
  ]
}

@defproc[(get-cell-formula
            [cell_axis string?]
            [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
            )
            string?]{

Get a cell's formula (as opposed to the calculated value of the formula). If the cell has no
formula, this will return an empty string.

  The @racket[_cell-axis] should be in the “A1” reference style.
  
  Limitations: Currently does not support array or shared formulae.
}

@defproc[(oa_date_number->date
            [oa_date_number number?]
            )
            date?]{

Convert an @tt{xlsx} numeric “date” value into Racket's @racket[date?] struct. Any fractional
portion of @racket[_oa_date_number] is ignored; this function's precision is to the day only.
                                            
Date values in @tt{xlsx} files are a plain number representing the count of days since 0 January
1900.

@examples[#:eval example-eval
  (date->string (oa_date_number->date 43359.1212121))
  (parameterize ([date-display-format 'rfc2822])
    (date->string (oa_date_number->date 44921.5601)))
]
}

@defproc[(get-sheet-dimension
            [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
            )
            (cons/c positive-integer? positive-integer?)]{

  Returns the current sheet's dimension as @racket[(cons _row _col)], such as @racket['(1 . 4)].

}

@defproc[(get-sheet-rows
            [xlsx_handler (or/c (is-a?/c read-xlsx%) (is-a?/c xlsx%))]
            )
            (listof (listof (or/c string? number?)))]{

  Returns all rows from the current loaded sheet.

}

@defproc[(sheet-name-rows
            [xlsx-file-path path-string?]
            [sheet-name string?]
            )
            (listof (listof (or/c string? number?)))]{

Reads the spreadsheet file specified by @racket[xlsx-file-path] and returns the data contained in
the sheet named @racket[_sheet-name]. If the file or the sheet do not exist, an exception is raised.

This is the most simple function for reading xlsx data. Use it when you don’t need to do any other
operations on the file.

}

@defproc[(sheet-ref-rows
            [xlsx-file-path path-string?]
            [sheet-index exact-nonnegative-integer?]
            )
            (listof (listof (or/c string? number?)))]{

Like @racket[sheet-name-rows], but uses a numeric index to specify sheet, starting from @code{0}.

}

@defclass[read-xlsx% object% ()]{

Class containing data read in from an existing @filepath{.xlsx} file. Convert to a @racket[xlsx%]
using @racket[from-read-to-write-xlsx].

}

@section{Write}

@defproc[(write-xlsx-file
            [xlsx (is-a?/c xlsx%)]
            [path path-string?])
            void?]{

Save the spreadsheet in @racket[_xlsx] to a @filepath{.xlsx} file. If the file exists it will be
silently overwritten.

}

@defproc[(from-read-to-write-xlsx
            [read_xlsx (is-a?/c read-xlsx%)])
            (is-a?/c xlsx%)]{

Converts a @racket[read-xlsx%] object (the kind produced within the body of
@racket[with-input-from-xlsx-file]) to a “writeable” @racket[xlsx%] object.

In general, the workflow to modify an existing @filepath{.xlsx} file is:

@codeblock{
  (with-input-from-xlsx-file
   "test.xlsx"
   (lambda (xlsx)
     (let ([write_xlsx (from-read-to-write-xlsx xlsx)])
       (send write_xlsx set-data-sheet-col-width!
             #:sheet_name "DataSheet"
             #:col_range "A-F" #:width 20)
       (write-xlsx-file write_xlsx "write_back.xlsx"))))
}

} @; defproc

@subsection{xlsx%}

@defclass[xlsx% object% ()]{

The @racket[xlsx%] class provides methods for changing a spreadsheet's data, contained in either
@tech{data sheets} or @tech{chart sheets}.

@defmethod[(add-data-sheet [#:sheet_name sheet string?]
                           [#:sheet_data cells (listof (listof any/c))]) void?]{

Adds a @deftech{data sheet} (as opposed to a @tech{chart sheet}), which holds normal data in cells.

Example:

@codeblock{
  (let ([xlsx (new xlsx%)])
    (send xlsx add-data-sheet 
      #:sheet_name "Sheet1" 
      #:sheet_data '(("chenxiao" "cx") (1 2))))
}

}
                                                                         
@defmethod[(set-data-sheet-col-width! [#:sheet_name sheet string?]
                                      [#:col_range cols string?]
                                      [#:width width number?]) void?]{

Manually set the width of one or more columns.

Note that by default, column widths are set automatically by their content. Use this method to
override the automatic sizing.

Example:

@codeblock{
  ;; set column A, B width: 50
  (send xlsx set-data-sheet-col-width! 
    #:sheet_name "DataSheet" 
    #:col_range "A-B" #:width 50)
}

}

@defmethod[(set-data-sheet-row-height! [#:sheet_name sheet string?]
                                       [#:row_range rows string?]
                                       [#:height height number?]) void?]{

Set the height of specified rows.

Example:

@codeblock{
  (send xlsx set-data-sheet-row-height!
    #:sheet_name "DataSheetWithStyle2"
    #:row_range "2-4" #:height 30)
}

}

@defmethod[(set-data-sheet-freeze-pane! [#:sheet_name sheet string?]
                                        [#:range range (cons/c exact-nonnegative-integer?
                                                               exact-nonnegative-integer?)]) void?]{

“Freezes” the given number of rows (counting from the top) and columns (counting from the left).

Example:

@codeblock{
  ;; freeze 1 row and 1 col
  (send xlsx set-data-sheet-freeze-pane! #:sheet_name "DataSheet" #:range '(1 . 1))
}

}


@defmethod[(add-data-sheet-cell-style! [#:sheet_name sheet string?]
                                       [#:cell_range range string?]
                                       [#:style style (listof (cons symbol? any/c))]) void?]{

Sets the @tech{cell style} for specific cells. The @racket[_range] string should be either a single
cell or a range of cells in “A1” reference style: @racket{C4} or @racket{B2-C3}.

}

@defmethod[(add-data-sheet-row-style!  [#:sheet_name sheet string?]
                                       [#:row_range range string?]
                                       [#:style style (listof (cons symbol? any/c))]) void?]{

Sets the @tech{cell style} for an entire row or range of rows. The @racket[_range] string should
contain either a single integer (@racket{1}) or a range like @racket{2-4}.

}

@defmethod[(add-data-sheet-col-style!  [#:sheet_name sheet string?]
                                       [#:col_range range string?]
                                       [#:style style (listof (cons symbol? any/c))]) void?]{

Sets the @tech{cell style} for an entire column or range of columns. The @racket[_range] string
should contain either a single integer (@racket{1}) or a range like @racket{2-4}.

}

@defmethod[(add-chart-sheet [#:sheet_name sheet string?]
                            [#:chart_type type (or/c 'linechart
                                                     'linechart3d
                                                     'barchart
                                                     'barchart3d
                                                     'piechart
                                                     'piechart3d)
                                                'linechart]
                            [#:topic topic string?]
                            [#:x_topic x-topic string?]
                            ) void?]{

Adds a @deftech{chart sheet} to the spreadsheet, which is a sheet containing only a chart. A chart
sheet draws its data from a @tech{data sheet}.

Examples:

@codeblock{
  (send xlsx add-chart-sheet
    #:sheet_name "LineChart1"
    #:topic "Horizontal Data"
    #:x_topic "Kg")

  (send xlsx add-chart-sheet
    #:sheet_name "LineChart1"
    #:chart_type 'bar
    #:topic "Horizontal Data"
    #:x_topic "Kg")
}

}

@defmethod[(set-chart-x-data! [#:sheet_name sheet string?]
                              [#:data_sheet_name data-sheet string?]
                              [#:data_range range string?]) void?]{

Set the x-axis data for a @tech{chart sheet}'s chart.

Example:

@codeblock{
  (send xlsx set-chart-x-data!
    #:sheet_name "LineChart1"
    #:data_sheet_name "DataSheet"
    #:data_range "B1-D1")
}

}

@defmethod[(add-chart-x-serial! [#:sheet_name sheet string?]
                                [#:data_sheet_name data-sheet string?]
                                [#:data_range range string?]
                                [#:y_topic y-topic string?]) void?]{

Adds a data range as as y-axis (series) data for a @tech{chart sheet}'s chart.


Example:

@codeblock{
  (send xlsx add-chart-serial!
    #:sheet_name "LineChart1"
    #:data_sheet_name "DataSheet"
    #:data_range "B2-D2" #:y_topic "CAT")
}


}

} @; defclass

@subsection{Cell Styles}

A @deftech{cell style} is a list of pairs, where each pair is a property/value pair according to
this grammar:

@racketgrammar*[#:literals (backgroundColor
                            fontSize
                            fontColor
                            fontName
                            numberPrecision
                            numberPercent
                            numberThousands
                            borderStyle thin medium thick dashed thinDashed
                                        mediumDashed thickDashed double hair dotted
                                        dashDot dashDotDot slantDashDot
                                        mediumDashDot mediumDashDotDot
                            borderDirection left right top bottom all
                            borderColor
                            dateFormat
                            horizontalAlign center
                            verticalAlign middle)
                (setting (backgroundColor . color-string)
                       (fontSize . positive-integer)
                       (fontName . string)
                       (fontColor . color-string)
                       (numberPrecision . positive-integer)
                       (numberPercent . boolean)
                       (numberThousands . boolean)
                       (borderStyle . border-line)
                       (borderDirection . dir)
                       (borderColor . color-string)
                       (dateFormat . ymd-format-string)
                       (horizontalAlign . h-alignment)
                       (verticalAlign . v-alignment)
                       )
                (border-line thin medium thick dashed thinDashed
                             mediumDashed thickDashed double hair dotted
                             dashDot dashDotDot slantDashDot
                             mediumDashDot mediumDashDotDot)
                (dir left right top bottom all)
                (h-alignment left right center)
                (v-alignment top bottom middle)
                (color-string hex-rgb-string color-name)]


When you change a cell's style, the settings you give will add to or overwrite the previous values.
Each affected cell retains its previous settings for any properties not identified.

This means the order in which you set styles is important.

Example:

@codeblock{
  (send xlsx add-data-sheet-cell-style!
    #:sheet_name "DataSheet"
    #:cell_range "B2-C3"
    #:style '( (backgroundColor . "FF0000") ))

  (send xlsx add-data-sheet-cell-style!
    #:sheet_name "DataSheet"
    #:cell_range "C3-D4"
    #:style '( (fontSize . 30) ))

  (send xlsx add-data-sheet-row-style!
    #:sheet_name "DataSheetWithStyle2"
    #:row_range "1-3" #:style '( (backgroundColor . "00C851") ))

  (send xlsx add-data-sheet-col-style!
    #:sheet_name "DataSheetWithStyle2"
    #:col_range "4-6" #:style '( (backgroundColor . "AA66CC") ))

}

After the above operations:

@itemlist[

@item{C2's style is @code{'((backgroundColor . "AA66CC"))}.}

@item{D3's style is @code{'((backgroundColor . "AA66CC") (fontSize . 30))}}

@item{C3's style is @code{'((backgroundColor . "00C851") (fontSize . 30))}}
]


@section{Complete Example}

@codeblock{
#lang racket

(require simple-xlsx)

(require racket/date)

(let ([xlsx (new xlsx%)]
      [sheet_data (list
                   (list "month/brand" "201601" "201602" "201603" "201604" "201605")
                   (list "CAT" 100 300 200 0.6934 (seconds->date (find-seconds 0 0 0 17 9 2018)))
                   (list "Puma" 200 400 300 139999.89223 (seconds->date (find-seconds 0 0 0 18 9 2018)))
                   (list "Asics" 300 500 400 23.34 (seconds->date (find-seconds 0 0 0 19 9 2018))))]
      [sheet_data2 (list
                    (list "month/brand" "201601" "201602" "201603" "201604" "201605" "")
                    (list "CAT" 100 300 200 0.6934 (seconds->date (find-seconds 0 0 0 17 9 2018)) "")
                    (list "Puma" 200 400 300 139999.89223 (seconds->date (find-seconds 0 0 0 18 9 2018)) "")
                    (list "Asics" 300 500 400 23.34 (seconds->date (find-seconds 0 0 0 19 9 2018)) "")
                    (list "" "" "" "" "" "" "Left")
                    (list "" "" "" "" "" "" "Right")
                    (list "" "" "" "" "" "" "Center")
                    (list "" "" "" "" "" "" "Top")
                    (list "" "" "" "" "" "" "Bottom")
                    (list "" "" "" "" "" "" "Middle")
                    (list "" "" "" "" "" "" "Center/Middle")
                    )])

  (send xlsx add-data-sheet #:sheet_name "DataSheet" #:sheet_data sheet_data)
  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheet" #:col_range "A-B" #:width 50)
  (send xlsx set-data-sheet-freeze-pane! #:sheet_name "DataSheet" #:range '(1 . 1))

  (send xlsx add-data-sheet #:sheet_name "DataSheetWithStyle" #:sheet_data sheet_data)
  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheetWithStyle" #:col_range "A-B" #:width 50)
  (send xlsx set-data-sheet-row-height! #:sheet_name "DataSheetWithStyle" #:row_range "3-4" #:height 30)
  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheetWithStyle" #:col_range "F" #:width 20)
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "A2-B3" #:style '( (backgroundColor . "00C851") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "C3-D4" #:style '( (backgroundColor . "AA66CC") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "B3-C4" #:style '( (fontSize . 20) (fontName . "Impact")))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "B1-C3" #:style '( (fontColor . "FF8800") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "E2-E2" #:style '( (numberPercent . #t) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "E3-E3" #:style '( (numberPrecision . 2) (numberThousands . #t)))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "E4-E4" #:style '( (numberPrecision . 0) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "B2-C4" #:style '( (borderStyle . dashed) (borderColor . "blue")))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "F2-F2" #:style '( (dateFormat . "yyyy-mm-dd") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "F3-F3" #:style '( (dateFormat . "yyyy/mm/dd") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle" #:cell_range "F4-F4" #:style '( (dateFormat . "yyyy年mm月dd日") ))

  (send xlsx add-data-sheet #:sheet_name "DataSheetWithStyle2" #:sheet_data sheet_data2)
  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheetWithStyle2" #:col_range "1-1" #:width 20)
  (send xlsx set-data-sheet-row-height! #:sheet_name "DataSheetWithStyle2" #:row_range "2-4" #:height 30)
  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheetWithStyle2" #:col_range "2-6" #:width 10)
  (send xlsx add-data-sheet-row-style! #:sheet_name "DataSheetWithStyle2" #:row_range "1-3" #:style '( (backgroundColor . "00C851") ))
  (send xlsx add-data-sheet-col-style! #:sheet_name "DataSheetWithStyle2" #:col_range "1-6" #:style '( (backgroundColor . "AA66CC") ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "B1-C3" #:style '( (backgroundColor . "FF8800") ))

  (send xlsx set-data-sheet-col-width! #:sheet_name "DataSheetWithStyle2" #:col_range "7" #:width 50)
  (send xlsx set-data-sheet-row-height! #:sheet_name "DataSheetWithStyle2" #:row_range "5-11" #:height 50)
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G5" #:style '( (horizontalAlign . left) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G6" #:style '( (horizontalAlign . right) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G7" #:style '( (horizontalAlign . center) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G8" #:style '( (verticalAlign . top) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G9" #:style '( (verticalAlign . bottom) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G10" #:style '( (verticalAlign . middle) ))
  (send xlsx add-data-sheet-cell-style! #:sheet_name "DataSheetWithStyle2" #:cell_range "G11"
        #:style '( (horizontalAlign . center) (verticalAlign . middle) ))

  (send xlsx add-chart-sheet #:sheet_name "LineChart1" #:topic "Horizontal Data" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "LineChart1" #:data_sheet_name "DataSheet" #:data_range "B1-D1")
  (send xlsx add-chart-serial! #:sheet_name "LineChart1" #:data_sheet_name "DataSheet" #:data_range "B2-D2" #:y_topic "CAT")
  (send xlsx add-chart-serial! #:sheet_name "LineChart1" #:data_sheet_name "DataSheet" #:data_range "B3-D3" #:y_topic "Puma")
  (send xlsx add-chart-serial! #:sheet_name "LineChart1" #:data_sheet_name "DataSheet" #:data_range "B4-D4" #:y_topic "Brooks")

  (send xlsx add-chart-sheet #:sheet_name "LineChart2" #:topic "Vertical Data" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "LineChart2" #:data_sheet_name "DataSheet" #:data_range "A2-A4" )
  (send xlsx add-chart-serial! #:sheet_name "LineChart2" #:data_sheet_name "DataSheet" #:data_range "B2-B4" #:y_topic "201601")
  (send xlsx add-chart-serial! #:sheet_name "LineChart2" #:data_sheet_name "DataSheet" #:data_range "C2-C4" #:y_topic "201602")
  (send xlsx add-chart-serial! #:sheet_name "LineChart2" #:data_sheet_name "DataSheet" #:data_range "D2-D4" #:y_topic "201603")

  (send xlsx add-chart-sheet #:sheet_name "LineChart3D" #:chart_type 'line3d #:topic "LineChart3D" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "LineChart3D" #:data_sheet_name "DataSheet" #:data_range "A2-A4" )
  (send xlsx add-chart-serial! #:sheet_name "LineChart3D" #:data_sheet_name "DataSheet" #:data_range "B2-B4" #:y_topic "201601")
  (send xlsx add-chart-serial! #:sheet_name "LineChart3D" #:data_sheet_name "DataSheet" #:data_range "C2-C4" #:y_topic "201602")
  (send xlsx add-chart-serial! #:sheet_name "LineChart3D" #:data_sheet_name "DataSheet" #:data_range "D2-D4" #:y_topic "201603")

  (send xlsx add-chart-sheet #:sheet_name "BarChart" #:chart_type 'bar #:topic "BarChart" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "BarChart" #:data_sheet_name "DataSheet" #:data_range "B1-D1" )
  (send xlsx add-chart-serial! #:sheet_name "BarChart" #:data_sheet_name "DataSheet" #:data_range "B2-D2" #:y_topic "CAT")
  (send xlsx add-chart-serial! #:sheet_name "BarChart" #:data_sheet_name "DataSheet" #:data_range "B3-D3" #:y_topic "Puma")
  (send xlsx add-chart-serial! #:sheet_name "BarChart" #:data_sheet_name "DataSheet" #:data_range "B4-D4" #:y_topic "Brooks")

  (send xlsx add-chart-sheet #:sheet_name "BarChart3D" #:chart_type 'bar3d #:topic "BarChart3D" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "BarChart3D" #:data_sheet_name "DataSheet" #:data_range "B1-D1" )
  (send xlsx add-chart-serial! #:sheet_name "BarChart3D" #:data_sheet_name "DataSheet" #:data_range "B2-D2" #:y_topic "CAT")
  (send xlsx add-chart-serial! #:sheet_name "BarChart3D" #:data_sheet_name "DataSheet" #:data_range "B3-D3" #:y_topic "Puma")
  (send xlsx add-chart-serial! #:sheet_name "BarChart3D" #:data_sheet_name "DataSheet" #:data_range "B4-D4" #:y_topic "Brooks")

  (send xlsx add-chart-sheet #:sheet_name "PieChart" #:chart_type 'pie #:topic "PieChart" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "PieChart" #:data_sheet_name "DataSheet" #:data_range "B1-D1" )
  (send xlsx add-chart-serial! #:sheet_name "PieChart" #:data_sheet_name "DataSheet" #:data_range "B2-D2" #:y_topic "CAT")

  (send xlsx add-chart-sheet #:sheet_name "PieChart3D" #:chart_type 'pie3d #:topic "PieChart3D" #:x_topic "Kg")
  (send xlsx set-chart-x-data! #:sheet_name "PieChart3D" #:data_sheet_name "DataSheet" #:data_range "B1-D1" )
  (send xlsx add-chart-serial! #:sheet_name "PieChart3D" #:data_sheet_name "DataSheet" #:data_range "B2-D2" #:y_topic "CAT")

  (write-xlsx-file xlsx "test.xlsx")

  (with-input-from-xlsx-file
   "test.xlsx"
   (lambda (xlsx)
     (printf "~a\n" (get-sheet-names xlsx))
     ;("DataSheet" "LineChart1" "LineChart2" "LineChart3D" "BarChart" "BarChart3D" "PieChart" "PieChart3D"))

     (load-sheet "DataSheet" xlsx)
     (printf "~a\n" (get-sheet-dimension xlsx)) ;(4 . 6)

     (printf "~a\n" (get-cell-value "A2" xlsx)) ;201601

     (let ([date_val (oa_date_number->date (get-cell-value "F2" xlsx))])
       (printf "~a,~a,~a\n" (date-year date_val) (date-month date_val) (date-day date_val)))
     ; 2018,9,17

     (printf "~a\n" (get-sheet-rows xlsx))
     ; '(("month/brand" 201601 201602 201603 201604 201605)
     ;   ("CAT" 100 300 200 0.6934 43360)
     ;   ("Puma" 200 400 300 139999.89223 43361)
     ;   ("Asics" 300 500 400 23.34 43362))
     
     ))
  )

  (with-input-from-xlsx-file
   "test.xlsx"
   (lambda (xlsx)
     (let ([write_xlsx (from-read-to-write-xlsx xlsx)])
       (send write_xlsx set-data-sheet-col-width!
             #:sheet_name "DataSheet"
             #:col_range "A-F" #:width 20)
       (write-xlsx-file write_xlsx "write_back.xlsx"))))

  (printf "~a\n" (sheet-name-rows "test.xlsx" "DataSheet"))
  ; ((month/brand 201601 201602 201603 201604 201605) (CAT 100 300 200 0.6934 43360) (Puma 200 400 300 139999.89223 43361) (Asics 300 500 400 23.34 43362))

  (printf "~a\n" (sheet-ref-rows "test.xlsx" 0))
  ; ((month/brand 201601 201602 201603 201604 201605) (CAT 100 300 200 0.6934 43360) (Puma 200 400 300 139999.89223 43361) (Asics 300 500 400 23.34 43362))
}
