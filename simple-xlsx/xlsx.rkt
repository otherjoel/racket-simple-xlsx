#lang racket

(require "lib/lib.rkt")

(provide (contract-out
          [xlsx% class?]
          [struct sheet
                  (
                  (name string?)
                  (seq exact-nonnegative-integer?)
                  (type symbol?)
                  (typeSeq exact-nonnegative-integer?)
                  (content (or/c data-sheet? line-chart-sheet?))
                  )]
          [struct data-sheet
                  (
                   (rows list?)
                   (width_hash hash?)
                   (color_hash hash?)
                   )]
          [struct line-chart-sheet
                  (
                   (topic string?)
                   (x_data_range data-range?)
                   (y_data_range_list list?)
                   )]
          [check-range (-> string? boolean?)]
          [check-data-range-valid (-> (is-a?/c xlsx%) string? string? boolean?)]
          [struct data-range
                  (
                   (sheet_name string?)
                   (range_str string?)
                   )]
          [convert-range (-> string? string?)]
          [range-length (-> string? exact-nonnegative-integer?)]
          [struct data-serial
                  (
                   (topic string?)
                   (data_range data-range?)
                   )]
          ))

(struct sheet ([name #:mutable] [seq #:mutable] [type #:mutable] [typeSeq #:mutable] [content #:mutable]))

(struct data-sheet ([rows #:mutable] [width_hash #:mutable] [color_hash #:mutable]))
(struct colAttr ([width #:mutable] [back_color #:mutable]))

(struct line-chart-sheet ([topic #:mutable] [x_data_range #:mutable] [y_data_range_list #:mutable]))
(struct data-range ([sheet_name #:mutable] [range_str #:mutable]))
(struct data-serial ([topic #:mutable] [data_range #:mutable]))

(define (check-range range_str)
  (if (regexp-match #rx"^[A-Z]+[0-9]+-[A-Z]+[0-9]+$" range_str)
      (let* ([range_part (regexp-split #rx"-" range_str)]
             [front_col_name #f]
             [front_col_index #f]
             [back_col_name #f]
             [back_col_index #f])
        (let ([items (regexp-match #rx"^([A-Z]+)([0-9]+)$" (first range_part))])
          (set! front_col_name (second items))
          (set! front_col_index (third items)))

        (let ([items (regexp-match #rx"^([A-Z]+)([0-9]+)$" (second range_part))])
          (set! back_col_name (second items))
          (set! back_col_index (third items)))
        
        (cond
         [(not (string=? front_col_name back_col_name))
          (error (format "range col name not consist[~a][~a]" front_col_name back_col_name))]
         [(> (string->number front_col_index) (string->number back_col_index))
          (error (format "range col index is invalid.[~a][~a]" front_col_index back_col_index))]
         [else
          #t]))
      (error (format "range format should like ^[A-Z]+[0-9]+-[A-Z]+[0-9]+$, but get ~a" range_str))))

(define (convert-range range_str)
  (when (check-range range_str)
        (let* ([items (regexp-match #rx"^([A-Z]+)([0-9]+)-[A-Z]+([0-9]+)$" range_str)]
               [col_name (second items)]
               [start_index (third items)]
               [end_index (fourth items)])
          (string-append "$" col_name "$" start_index ":$" col_name "$" end_index))))

(define (range-length range_str)
  (let ([numbers (regexp-match* #rx"([0-9]+)" range_str)])
    (add1 (- (string->number (second numbers)) (string->number (first numbers))))))

(define (check-data-range-valid xlsx sheet_name range_str)
  (when (check-range range_str)
        (let* ([rows (data-sheet-rows (sheet-content (send xlsx get-sheet-by-name sheet_name)))]
               [first_row (first rows)]
               [col_name (first (regexp-match* #rx"([A-Z]+)" range_str))]
               [col_number (sub1 (abc->number col_name))]
               [row_range (regexp-match* #rx"([0-9]+)" range_str)]
               [row_start_index (string->number (first row_range))]
               [row_end_index (string->number (second row_range))])
          (cond
           [(< (length first_row) (add1 col_number))
            (error (format "no such column[~a]" col_name))]
           [(> (length rows) row_end_index)
            (error (format "end index beyond data range[~a]" row_end_index))]
           [else
            #t]))))

(define xlsx%
  (class object%
         (super-new)
         
         (field 
          [sheets '()]
          [sheet_name_map (make-hash)]
          )
         
         (define/public (add-data-sheet sheet_name sheet_data)
           (if (not (hash-has-key? sheet_name_map sheet_name))
               (let* ([sheet_length (length sheets)]
                      [seq (add1 sheet_length)]
                      [type_seq (add1 (length (filter (lambda (rec) (eq? (sheet-type rec) 'data)) sheets)))])
                 (set! sheets `(,@sheets
                                ,(sheet
                                  sheet_name
                                  seq
                                  'data
                                  type_seq
                                  (data-sheet sheet_data (make-hash) (make-hash)))))
                 (hash-set! sheet_name_map sheet_name (sub1 seq)))
               (error (format "duplicate sheet name[~a]" sheet_name))))
         
         (define/public (get-sheet-by-name sheet_name)
           (list-ref sheets (hash-ref sheet_name_map sheet_name)))
         
         (define/public (get-range-data sheet_name range_str)
           (let* ([data_sheet (get-sheet-by-name sheet_name)]
                  [col_name (first (regexp-match* #rx"([A-Z]+)" range_str))]
                  [col_number (sub1 (abc->number col_name))]
                  [row_range (regexp-match* #rx"([0-9]+)" range_str)]
                  [row_start_index (string->number (first row_range))]
                  [row_end_index (string->number (second row_range))])
             (let loop ([loop_list (data-sheet-rows (sheet-content data_sheet))]
                        [row_count 1]
                        [result_list '()])
               (if (not (null? loop_list))
                   (if (and (>= row_count row_start_index) (<= row_count row_end_index))
                       (loop (cdr loop_list) (add1 row_count) (cons (list-ref (car loop_list) col_number) result_list))
                       (loop (cdr loop_list) (add1 row_count) result_list))
                   (reverse result_list)))))

         (define/public (add-line-chart-sheet sheet_name topic)
           (if (not (hash-has-key? sheet_name_map sheet_name))
               (let* ([sheet_length (length sheets)]
                      [seq (add1 sheet_length)]
                      [type_seq (add1 (length (filter (lambda (rec) (eq? (sheet-type rec) 'chart)) sheets)))])
                 (set! sheets `(,@sheets
                                ,(sheet
                                  sheet_name
                                  seq
                                  'chart
                                  type_seq
                                  (line-chart-sheet topic (data-range "" "") '()))))
                 (hash-set! sheet_name_map sheet_name (sub1 seq)))
               (error (format "duplicate sheet name[~a]" sheet_name))))
                 
         (define/public (set-line-chart-x-data! line_chart_sheet_name data_sheet_name data_range)
           (when (check-data-range-valid this data_sheet_name data_range)
                 (set-line-chart-sheet-x_data_range! (sheet-content (get-sheet-by-name line_chart_sheet_name)) (data-range data_sheet_name data_range))))

         (define/public (add-line-chart-y-data! line_chart_sheet_name y_topic sheet_name data_range)
           (when (check-data-range-valid this sheet_name data_range)
                 (set-line-chart-sheet-y_data_range_list! (sheet-content (get-sheet-by-name line_chart_sheet_name)) `(,@(line-chart-sheet-y_data_range_list (sheet-content (get-sheet-by-name line_chart_sheet_name))) ,(data-serial y_topic (data-range sheet_name data_range))))))
         
         (define/public (sheet-ref sheet_seq)
           (list-ref sheets sheet_seq))
         
         (define/public (set-sheet-col-width! sheet col_range width)
           (hash-set! (data-sheet-width_hash (sheet-content sheet)) col_range width))

         (define/public (set-sheet-col-color! sheet col_range color)
           (hash-set! (data-sheet-color_hash (sheet-content sheet)) col_range color))
         ))
