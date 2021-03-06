#lang racket

(require rackunit/text-ui)

(require rackunit "../../../../writer/xl/drawings/drawing.rkt")

(define test-drawing
  (test-suite
   "test-drawing"

   (test-case
    "test-drawing"

    (check-equal? (write-drawing)
                  (string-append
                   "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                   "<xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><xdr:absoluteAnchor><xdr:pos x=\"0\" y=\"0\"/><xdr:ext cx=\"9311355\" cy=\"6088879\"/><xdr:graphicFrame macro=\"\"><xdr:nvGraphicFramePr><xdr:cNvPr id=\"2\" name=\"图表 1\"/><xdr:cNvGraphicFramePr><a:graphicFrameLocks noGrp=\"1\"/></xdr:cNvGraphicFramePr></xdr:nvGraphicFramePr><xdr:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></xdr:xfrm><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"rId1\"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:absoluteAnchor></xdr:wsDr>"))
    )))

(run-tests test-drawing)
