(function () {
    'use strict';

    if (window.__elementumWebProgressiveInstalled) {
        return;
    }
    window.__elementumWebProgressiveInstalled = true;

    var nativeFetch = window.fetch.bind(window);
    var bridgeHost = window.location.hostname.indexOf(':') >= 0
        ? '[' + window.location.hostname + ']'
        : window.location.hostname;
    var bridgeBase = 'http://' + bridgeHost + ':65222';
    var activeRun = 0;
    var requestFinished = false;
    var requestFailed = '';
    var currentSession = '';
    var lastRenderKey = '';

    function injectStyle() {
        if (document.getElementById('elementum-progressive-style')) {
            return;
        }

        var style = document.createElement('style');
        style.id = 'elementum-progressive-style';
        style.textContent = [
            '#elementum-progressive-overlay{position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.78);display:flex;align-items:center;justify-content:center;padding:18px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}',
            '#elementum-progressive-modal{width:min(1080px,96vw);max-height:92vh;display:flex;flex-direction:column;background:#161b22;color:#e6edf3;border:1px solid #30363d;border-radius:10px;box-shadow:0 18px 70px rgba(0,0,0,.65);overflow:hidden}',
            '#elementum-progressive-head{display:flex;align-items:center;gap:12px;padding:15px 18px;border-bottom:1px solid #30363d}',
            '#elementum-progressive-title{font-size:18px;font-weight:700;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
            '#elementum-progressive-count{font-size:13px;color:#9da7b3;white-space:nowrap}',
            '#elementum-progressive-close{border:0;background:transparent;color:#c9d1d9;font-size:28px;line-height:1;cursor:pointer;padding:0 3px}',
            '#elementum-progressive-status{padding:10px 18px;border-bottom:1px solid #30363d;color:#9da7b3;font-size:13px}',
            '#elementum-progressive-list{overflow:auto;padding:10px;display:flex;flex-direction:column;gap:8px}',
            '.elementum-progressive-item{width:100%;text-align:left;background:#21262d;color:#e6edf3;border:1px solid #30363d;border-radius:7px;padding:11px 13px;cursor:pointer;transition:background .12s,border-color .12s,transform .12s}',
            '.elementum-progressive-item:hover{background:#292f37;border-color:#58a6ff;transform:translateY(-1px)}',
            '.elementum-progressive-item:disabled{opacity:.55;cursor:wait;transform:none}',
            '.elementum-progressive-main{font-size:14px;font-weight:650;line-height:1.35}',
            '.elementum-progressive-name{font-size:13px;color:#b8c0ca;line-height:1.4;margin-top:5px;word-break:break-word}',
            '#elementum-progressive-empty{padding:42px 18px;text-align:center;color:#9da7b3}',
            '.elementum-progressive-spinner{display:inline-block;width:14px;height:14px;border:2px solid #4b5563;border-top-color:#58a6ff;border-radius:50%;animation:elementum-progressive-spin .8s linear infinite;vertical-align:-2px;margin-right:8px}',
            '@keyframes elementum-progressive-spin{to{transform:rotate(360deg)}}',
            '@media(max-width:640px){#elementum-progressive-overlay{padding:0}#elementum-progressive-modal{width:100vw;max-height:100vh;height:100vh;border-radius:0}.elementum-progressive-item{padding:12px 10px}}'
        ].join('');
        document.head.appendChild(style);
    }

    function cleanKodiMarkup(value) {
        return String(value || '')
            .replace(/\[\/?B\]/gi, '')
            .replace(/\[\/?I\]/gi, '')
            .replace(/\[COLOR(?:=[^\]]+)?\]/gi, '')
            .replace(/\[\/COLOR\]/gi, '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function getOverlay() {
        return document.getElementById('elementum-progressive-overlay');
    }

    function closeOverlay(sendCancel) {
        activeRun += 1;
        var overlay = getOverlay();
        if (overlay && overlay.parentNode) {
            overlay.parentNode.removeChild(overlay);
        }
        if (sendCancel) {
            nativeFetch(bridgeBase + '/cancel', {method: 'POST'}).catch(function () {});
        }
    }

    function openOverlay() {
        injectStyle();
        closeOverlay(false);

        var overlay = document.createElement('div');
        overlay.id = 'elementum-progressive-overlay';

        var modal = document.createElement('div');
        modal.id = 'elementum-progressive-modal';

        var head = document.createElement('div');
        head.id = 'elementum-progressive-head';

        var title = document.createElement('div');
        title.id = 'elementum-progressive-title';
        title.textContent = 'Поиск торрентов';

        var count = document.createElement('div');
        count.id = 'elementum-progressive-count';
        count.textContent = '0 результатов';

        var close = document.createElement('button');
        close.id = 'elementum-progressive-close';
        close.type = 'button';
        close.title = 'Отмена';
        close.textContent = '×';
        close.addEventListener('click', function () {
            closeOverlay(true);
        });

        var status = document.createElement('div');
        status.id = 'elementum-progressive-status';
        status.innerHTML = '<span class="elementum-progressive-spinner"></span>Запуск поиска…';

        var list = document.createElement('div');
        list.id = 'elementum-progressive-list';

        var empty = document.createElement('div');
        empty.id = 'elementum-progressive-empty';
        empty.textContent = 'Ожидаем первые результаты провайдеров…';
        list.appendChild(empty);

        head.appendChild(title);
        head.appendChild(count);
        head.appendChild(close);
        modal.appendChild(head);
        modal.appendChild(status);
        modal.appendChild(list);
        overlay.appendChild(modal);
        document.body.appendChild(overlay);

        overlay.addEventListener('click', function (event) {
            if (event.target === overlay) {
                closeOverlay(true);
            }
        });
    }

    function setStatus(message, spinning) {
        var status = document.getElementById('elementum-progressive-status');
        if (!status) {
            return;
        }
        status.textContent = '';
        if (spinning) {
            var spinner = document.createElement('span');
            spinner.className = 'elementum-progressive-spinner';
            status.appendChild(spinner);
        }
        status.appendChild(document.createTextNode(message));
    }

    function selectTorrent(choice, button) {
        var buttons = document.querySelectorAll('.elementum-progressive-item');
        Array.prototype.forEach.call(buttons, function (item) {
            item.disabled = true;
        });
        setStatus('Запускаем выбранный торрент…', true);

        nativeFetch(bridgeBase + '/select', {
            method: 'POST',
            headers: {'Content-Type': 'text/plain;charset=UTF-8'},
            body: JSON.stringify({choice: choice})
        }).then(function (response) {
            if (!response.ok) {
                throw new Error('Bridge HTTP ' + response.status);
            }
            button.style.borderColor = '#3fb950';
            window.setTimeout(function () {
                closeOverlay(false);
            }, 250);
        }).catch(function (error) {
            Array.prototype.forEach.call(buttons, function (item) {
                item.disabled = false;
            });
            setStatus('Не удалось выбрать торрент: ' + String(error), false);
        });
    }

    function renderState(state) {
        var overlay = getOverlay();
        if (!overlay || !state || !state.active) {
            return;
        }

        var items = Array.isArray(state.items) ? state.items : [];
        var renderKey = String(state.session || '') + ':' + String(state.updated_at || '') + ':' + items.length;
        if (renderKey === lastRenderKey) {
            return;
        }
        lastRenderKey = renderKey;
        currentSession = String(state.session || '');

        var title = document.getElementById('elementum-progressive-title');
        var count = document.getElementById('elementum-progressive-count');
        var list = document.getElementById('elementum-progressive-list');
        if (!title || !count || !list) {
            return;
        }

        title.textContent = cleanKodiMarkup(state.title) || 'Выберите торрент';
        count.textContent = items.length + (items.length === 1 ? ' результат' : ' результатов');
        setStatus('Результаты добавляются по мере ответа провайдеров', true);

        list.textContent = '';
        if (!items.length) {
            var empty = document.createElement('div');
            empty.id = 'elementum-progressive-empty';
            empty.textContent = 'Провайдеры пока не вернули подходящих торрентов…';
            list.appendChild(empty);
            return;
        }

        items.forEach(function (rawItem, index) {
            var lines = String(rawItem || '').split('\n');
            var button = document.createElement('button');
            button.type = 'button';
            button.className = 'elementum-progressive-item';

            var main = document.createElement('div');
            main.className = 'elementum-progressive-main';
            main.textContent = cleanKodiMarkup(lines[0]);

            var name = document.createElement('div');
            name.className = 'elementum-progressive-name';
            name.textContent = cleanKodiMarkup(lines[1] || lines[0]);

            button.appendChild(main);
            button.appendChild(name);
            button.addEventListener('click', function () {
                selectTorrent(index, button);
            });
            list.appendChild(button);
        });
    }

    function pollState(runId, startedAt) {
        if (runId !== activeRun || !getOverlay()) {
            return;
        }

        nativeFetch(bridgeBase + '/state', {cache: 'no-store'})
            .then(function (response) {
                if (!response.ok) {
                    throw new Error('Bridge HTTP ' + response.status);
                }
                return response.json();
            })
            .then(function (state) {
                if (runId !== activeRun || !getOverlay()) {
                    return;
                }

                if (state.active) {
                    renderState(state);
                    if (state.done) {
                        closeOverlay(false);
                        return;
                    }
                } else if (requestFinished) {
                    if (requestFailed) {
                        setStatus('Ошибка запуска поиска: ' + requestFailed, false);
                    } else {
                        setStatus('Запрос завершён без окна выбора торрента', false);
                        window.setTimeout(function () {
                            closeOverlay(false);
                        }, 1200);
                        return;
                    }
                } else if (Date.now() - startedAt > 15000) {
                    setStatus('Поиск выполняется, но окно результатов ещё не создано…', true);
                }

                if (Date.now() - startedAt > 240000) {
                    setStatus('Превышено время ожидания результатов', false);
                    return;
                }

                window.setTimeout(function () {
                    pollState(runId, startedAt);
                }, 500);
            })
            .catch(function (error) {
                if (runId !== activeRun || !getOverlay()) {
                    return;
                }
                setStatus('Web bridge недоступен: ' + String(error), false);
                window.setTimeout(function () {
                    pollState(runId, startedAt);
                }, 1500);
            });
    }

    function isTorrentSelectionRequest(input) {
        var rawUrl = typeof input === 'string'
            ? input
            : (input && input.url ? input.url : '');
        if (!rawUrl) {
            return false;
        }

        var url;
        try {
            url = new URL(rawUrl, window.location.href);
        } catch (error) {
            return false;
        }

        if (!url.searchParams.has('external')) {
            return false;
        }

        return /\/(?:links|forcelinks|download)(?:\/|$)/i.test(url.pathname);
    }

    function startWebSelection(input, init) {
        openOverlay();
        requestFinished = false;
        requestFailed = '';
        currentSession = '';
        lastRenderKey = '';
        var runId = ++activeRun;
        var startedAt = Date.now();

        nativeFetch(bridgeBase + '/arm', {method: 'POST'})
            .then(function (response) {
                if (!response.ok) {
                    throw new Error('Bridge HTTP ' + response.status);
                }

                nativeFetch(input, init)
                    .then(function () {
                        requestFinished = true;
                    })
                    .catch(function (error) {
                        requestFailed = String(error);
                        requestFinished = true;
                    });

                pollState(runId, startedAt);
            })
            .catch(function (error) {
                requestFailed = String(error);
                requestFinished = true;
                setStatus('Не удалось включить Web bridge: ' + requestFailed, false);
            });
    }

    window.fetch = function (input, init) {
        if (!isTorrentSelectionRequest(input)) {
            return nativeFetch(input, init);
        }

        startWebSelection(input, init);

        return Promise.resolve(new Response('{}', {
            status: 200,
            headers: {'Content-Type': 'application/json'}
        }));
    };

    console.info('Elementum progressive torrent selector for Web UI is active');
})();
