;; requires Nunja
(load "Nunja")

(set &html (NunjaMarkupOperator operatorWithTag:"html" prefix:<<-END
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END))

(global XMLNS "http://www.w3.org/1999/xhtml")

(macro markup (*names)
     `(progn
            (',*names each:
                 (do (name)
                     (set stringName (name stringValue))
                     (set expression
                          (list 'global ((+ "&" stringName) symbolValue) '(NunjaMarkupOperator operatorWithTag:stringName)))
                     (eval expression)))))

# add tags as needed
(markup a
        body
        br
        button
        div
        fieldset
        form
        head
        h1
        h2
        h3
        h4
        h5
        h6
        img
        input
	label
        li
        link
        meta
        ol
        option
        p
        pre
        script
        select
        span
        strong
        style
        table
        td
	textarea
        th
        title
        tr
        tbody
        ul)
