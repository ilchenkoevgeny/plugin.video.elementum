# -*- coding: utf-8 -*-
import os

import xbmc
import xbmcaddon
import xbmcgui


ADDON = xbmcaddon.Addon('plugin.video.elementum')
ADDON_PATH = ADDON.getAddonInfo('path')


class StaticProbeDialog(xbmcgui.WindowXMLDialog):
    def __init__(self, *args, **kwargs):
        self.title = kwargs.get('title', 'Elementum GUI probe')
        self.rows = list(kwargs.get('rows') or [])
        self.choice = -1

    def onInit(self):
        try:
            xbmc.log(
                '[plugin.video.elementum] STATIC_PROBE onInit thread started',
                xbmc.LOGWARNING,
            )
            self.getControl(32501).setLabel(self.title)
            control = self.getControl(32503)
            control.reset()

            for index, row in enumerate(self.rows):
                item = xbmcgui.ListItem(label=row, label2='Static GUI test')
                item.setProperty('index', str(index))
                control.addItem(item)

            if self.rows:
                control.selectItem(0)
                self.setFocusId(32503)

            xbmc.log(
                '[plugin.video.elementum] STATIC_PROBE onInit complete rows=%d control_size=%d'
                % (len(self.rows), control.size()),
                xbmc.LOGWARNING,
            )
        except Exception as exc:
            xbmc.log(
                '[plugin.video.elementum] STATIC_PROBE onInit failed: %r' % exc,
                xbmc.LOGERROR,
            )
            raise

    def onClick(self, control_id):
        if control_id == 32500:
            self.close()
            return

        if control_id == 32503:
            selected = self.getControl(32503).getSelectedItem()
            if selected is not None:
                try:
                    self.choice = int(selected.getProperty('index'))
                except Exception:
                    self.choice = -1
            self.close()

    def onAction(self, action):
        if action.getId() in (9, 10, 92, 110):
            self.close()


def main():
    xbmc.log(
        '[plugin.video.elementum] STATIC_PROBE script started',
        xbmc.LOGWARNING,
    )

    window = StaticProbeDialog(
        'DialogSelectLarge.xml',
        ADDON_PATH,
        'Default',
        title='Elementum: проверка окна',
        rows=[
            'Тестовая строка № 1',
            'Тестовая строка № 2',
            'Тестовая строка № 3',
        ],
    )

    try:
        window.doModal()
        xbmc.log(
            '[plugin.video.elementum] STATIC_PROBE dialog closed choice=%d'
            % window.choice,
            xbmc.LOGWARNING,
        )
    finally:
        del window


if __name__ == '__main__':
    main()
