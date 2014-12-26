up.api = (->

  rememberSource = ($element) ->
    $element.attr("up-source", location.href)

  recallSource = ($element) ->
    $source = $element.closest("[up-source]")
    $source.attr("up-source") || location.href

  replace = (selector, url, options) ->
    $target = $(selector)
    $target = up.util.$createElementFromSelector(selector) unless $target.length
    $target.addClass("up-loading")
    options = up.util.options(options, history: { url: url })

    up.util.get(url, selector: selector)
      .done (html) ->
        $target.removeClass("up-loading")
        implantFragment(selector, html, options)
      .fail(up.util.error)

  implantFragment = (selector, html, options) ->
    $target = $(selector)
    # jQuery cannot construct transient elements that contain
    # <html> or <body> tags, so we're using the native browser
    # API to grep through the HTML
    htmlElement = up.util.createElementFromHtml(html)
    if fragment = htmlElement.querySelector(selector)
      $target.replaceWith(fragment)
      title = htmlElement.querySelector("title").textContent
      if options.history?.url
        document.title = title if title
        # For some reason we need to recreate the HTML element at this point.
        # We cannot reuse the element we created earlier. I have no idea why.
        htmlElement = up.util.createElementFromHtml(html)
        # We're pushing the last HTML <body> we got from the server
        # and *NOT* the current document.body.innerHTML. The reason is
        # that our current document body has already been compiled
        # and might have suffered non-idempotent transformations during
        # transformation.
#        console.log("pushing", htmlElement.querySelector('body').innerHTML)
        # historyOptions = up.util.options(historyOptions, method: 'push', url: url)
        method = options.history.method || 'push'
        up.past[method](options.history.url, htmlElement.querySelector('body').innerHTML)
        # Remember where the element came from so we can make
        # smaller page loads in the future (does this even make sense?).
        rememberSource($target)
      compile(fragment)
    else
      up.util.error("Could not find selector (#{selector}) in response (#{html})")

  compile = (fragment) ->
    console.log("compiling fragment")
    up.bus.emit('fragment:ready', $(fragment))

  reload = (selector) ->
    replace(selector, recallSource($(selector)))

  remove = (elementOrSelector) ->
    $(elementOrSelector).remove()

  submit = (form) ->
    $form = $(form)
    successSelector = $form.attr('up-target') || 'body'
    failureSelector = $form.attr('up-fail-target') || up.util.createSelectorFromElement($form)
    $form.addClass('up-loading')
    request = {
      url: $form.attr('action') || location.href
      type: $form.attr('method') || 'POST',
      data: $form.serialize()
    }
    $.ajax(request).always((html, textStatus, xhr) ->
      $form.removeClass('up-loading')
      if redirectLocation = xhr.getResponseHeader('X-Up-Previous-Redirect-Location')
        implantFragment(successSelector, html, history: { url: redirectLocation })

      else
        implantFragment(failureSelector, html)
    )

  visit = (url, options) ->
    console.log("up.visit", url)
    replace('body', url, options)

  follow = (link, options) ->
    $link = $(link)
    url = $link.attr("href")
    selector = $link.attr("up-target") || 'body'
    replace(selector, url, options)

  up.app.on 'click', 'a[up-target], a[up-follow]', (event, $link) ->
    event.preventDefault()
    follow($link)

  up.app.on 'submit', 'form[up-target]', (event, $form) ->
    event.preventDefault()
    submit($form)

  replace: replace
  reload: reload
  remove: remove
  submit: submit
  visit: visit
  follow: follow
  compile: compile

)()

up.util.extend(up, up.api)
