$(function () {

    class Params {
        constructor(htmlWidth) {

            this.firstPasukFontSize = 3;
            this.secondPasukFontSize = 3;
            this.tajPasukFontSize = 3;

            this.firstPasukLineHeight = 4;
            this.secondPasukLineHeight = 4;
            this.tajPasukLineHeight = 4;

            this.firstPasukFontColor = 'DarkRed';
            this.secondPasukFontColor = 'DarkGreen';
            this.tajPasukFontColor = 'DarkBlue';

            this.transformScaleY = 'scaleY(1.2)';

            this.firstPasukFontFamily = 'SBLBibLit';
            this.secondPasukFontFamily = 'SBLBibLit';
            this.tajPasukFontFamily = 'SBLBibLit';

            this.firstPasukFontWeight = 'normal';
            this.secondPasukFontWeight = 'normal';
            this.tajPasukFontWeight = 'normal';

            this.fontSizeTypeDesc = 'vw';
            this.lineHeightTypeDesc = 'vw';

            this.pasukPaddingTop = '12px';
            this.pasukPaddingBottom = '26px';

            this.divPasukPadding = '44px';

            this.firstPasukPaddingTop = '3vw';
            this.firstPasukPadding = '44px';
            this.secondPasukPadding = '44px';
            this.tajPasukPadding = '44px';
            this.tajPasukPaddingBotton = '3vw';

            if (htmlWidth <= 1080) {
                this.firstPasukFontSize = 6;
                this.secondPasukFontSize = 6;
                this.tajPasukFontSize = 6;

                this.firstPasukLineHeight = 7;
                this.secondPasukLineHeight = 7;
                this.tajPasukLineHeight = 7;

                this.pasukPaddingTop = '22px';
                this.pasukPaddingBottom = '36px';

                this.divPasukPadding = '44px';

                this.firstPasukPaddingTop = '8vw';
                this.firstPasukPadding = '1vw';
                this.secondPasukPadding = '1vw';
                this.tajPasukPadding = '1vw';
                this.tajPasukPaddingBotton = '8vw';

                return;
            }

            if (htmlWidth <= 900) {
                this.firstPasukFontSize = 5;
                this.secondPasukFontSize = 5;
                this.tajPasukFontSize = 5;

                this.firstPasukLineHeight = 6;
                this.secondPasukLineHeight = 6;
                this.tajPasukLineHeight = 6;

                this.pasukPaddingTop = '22px';
                this.pasukPaddingBottom = '36px';

                this.divPasukPadding = '18px';

                this.firstPasukPaddingTop = '10vw';
                this.firstPasukPadding = '1vw';
                this.secondPasukPadding = '1vw';
                this.tajPasukPadding = '1vw';
                this.tajPasukPaddingBotton = '10vw';

                return;
            }
        }
    }

    $.fn.isOnScreen = function () {

        var win = $(window);

        var viewport = {
            top: win.scrollTop(),
            left: win.scrollLeft()
        };
        viewport.right = viewport.left + win.width();
        viewport.bottom = viewport.top + win.height();

        var paddingBottom = 700;
        var paddingDiv2Passok = 100;

        // Draw viewport
        $('#viewportDiv').height(win.height() - paddingBottom);
        $('#viewportDiv').width(win.width());
        $('#viewportDiv').css('left', viewport.left);
        $('#viewportDiv').css('top', 1);

        //console.log(viewport);
        //console.log(`win - scrollTop: ${win.scrollTop()}, Height: ${win.height()}, Width: ${win.width()}, `);

        viewport.bottom -= paddingBottom;

        var bounds = this.offset();
        bounds.top += paddingDiv2Passok;
        bounds.right = bounds.left + this.outerWidth();
        bounds.bottom = bounds.top + this.outerHeight();

        bounds.bottom += paddingDiv2Passok;

        var res = !(viewport.right < bounds.left || viewport.left > bounds.right || viewport.bottom < bounds.top || viewport.top > bounds.bottom);

        if (res == true) {
            // Draw viewport
            /*$('#viewportDiv').height(viewport.bottom - viewport.top);
            $('#viewportDiv').width(viewport.right - viewport.left);
            $('#viewportDiv').css('left', viewport.left);
            $('#viewportDiv').css('top', viewport.top);*/

            console.log(`win - scrollTop: ${win.scrollTop()}, Height: ${win.height()}, Width: ${win.width()}, `);

        }

        return res;
    };

    $.removeNonAscii = function (str) {

        if ((str === null) || (str === ''))
            return false;
        else
            str = str.toString();

        return str.replace(/[^\x20-\x7E]/g, '');
    };

    $('h3').css('color', 'maroon');

    //setAccordions();

    $('.accordion.aliya').accordion({
        heightStyle: 'content',
        collapsible: false,
        autoHeight: true,
        activate: function (event, ui) {
            //updateFirstTopRow();
        },
        active: null
    });

    $('.accordion.verse').accordion({
        heightStyle: 'content',
        collapsible: false,
        autoHeight: true,
        icons: false,
        active: null
    });

    function setAccordions() {
        $('.accordion.aliya').accordion({
            heightStyle: 'content',
            collapsible: false,
            autoHeight: true,
            activate: function (event, ui) {
                //updateFirstTopRow();
            },
            active: null
        });
        $('.accordion.verse').accordion({
            heightStyle: 'content',
            collapsible: false,
            autoHeight: true,
            icons: false,
            active: null
        });
    }

    $(window).scroll(function () {
        /*var $rowTop = $('.container.body-content');
        var eTop = $rowTop.offset().top;
        var calc = eTop - $(window).scrollTop();
        var msg = `eTop: ${eTop}, win.sTop(): ${$(window).scrollTop()}, Calc: ${calc}`;
        console.log(msg);*/
        var contentTop = $('.container.body-content').offset().top;
        if (contentTop <= 0) {
            //updateFirstTopRow();
        }
    });

    $(window).resize(function () {
        let params = new Params($('html').width());
        changeBaseHtml(params);
    });

    function updateFirstTopRow() {
        var contentTop = $('.container.body-content').offset().top;
        var msg = `contentTop: ${contentTop}`;
        //console.log(msg);
        if (contentTop <= 0) {
            var setTop = (contentTop * -1) + 1500;
            $('.container.body-content').css('margin-top', setTop + 'px');
            var msg2 = `After setting top: ${setTop}`;
            console.log(msg2);
        }
    }

    // -- --
    let params = new Params($('html').width());

    //params.tajPasukFontWeight = 'bold';

    //params.fontFamilyMikra = 'SBL Hebrew';
    //params.fontFamilyMikra = 'SBLBibLit';
    //params.fontFamilyTaj = 'MekorotRashi';

    params.firstPasukFontFamily = 'SBLBibLit';
    params.secondPasukFontFamily = 'SBLBibLit';
    params.tajPasukFontFamily = 'SBLBibLit';

    //params.firstPasukFontFamily = 'Taamey Frank CLM';
    //params.secondPasukFontFamily = 'Taamey Frank CLM';

    //params.firstPasukFontFamily = 'Hadasim CLM';
    //params.secondPasukFontFamily = 'Hadasim CLM';

    params.tajPasukFontFamily = 'Guttman Vilna';
    params.tajPasukFontFamily = 'David';
    params.tajPasukFontFamily = 'Mekorot-Vilna';
    params.tajPasukFontFamily = 'Hadasim CLM';
    params.tajPasukFontFamily = 'Hebrew_bold';
    params.tajPasukFontFamily = 'Tahoma';
    params.tajPasukFontFamily = 'Guttman Vilna';
    params.tajPasukFontFamily = 'Taamey Frank CLM';
    params.tajPasukFontFamily = 'MFT NarkisClassic';
    //params.tajPasukFontFamily = 'Narkisim';
    params.tajPasukFontFamily = 'Guttman-Soncino';
    //params.tajPasukFontFamily = 'Guttman-Toledo';
    params.tajPasukFontFamily = 'Guttman Drogolin';
    //params.tajPasukFontFamily = 'Noto Serif Hebrew Black';
    //params.tajPasukFontFamily = 'Noto Serif Hebrew Black';
    //params.tajPasukFontFamily = 'Noto Serif Hebrew Condensed';
    params.tajPasukFontFamily = 'SBLBibLit';

    // Update sizes
    params.firstPasukLineHeight = 49;
    params.firstPasukFontSize = 43;
    params.secondPasukFontSize = 42;
    params.tajPasukFontSize = 40;

    params.firstPasukLineHeight = 66;
    params.firstPasukFontSize = 58;
    params.secondPasukFontSize = 58;
    params.tajPasukFontSize = 48;

    params.firstPasukLineHeight = 66;
    params.secondPasukLineHeight = 66;
    params.tajPasukLineHeight = 58;

    params.firstPasukFontSize = 54;
    params.secondPasukFontSize = 54;
    params.tajPasukFontSize = 52;

    // VM
    params.fontSizeTypeDesc = 'vw';
    params.lineHeightTypeDesc = 'vw';

    params.firstPasukFontSize = 3;
    params.secondPasukFontSize = 3;
    params.tajPasukFontSize = 3;

    params.firstPasukLineHeight = 4;
    params.secondPasukLineHeight = 4;
    params.tajPasukLineHeight = 4;

    params.sectionZoom = '96%';
    params.sectionZoom = '100%';
    params.tajPasukFontColor = 'rgb(27 23 237)';
    params.tajPasukFontColor = '#A1004A';//'#BC005E';//'#800040';
    params.tajPasukFontColor = 'rgb(128 0 0)'; // Maroon
    params.tajPasukFontColor = 'rgb(0 100 0)'; // DarkGreen

    // RGB
    params.firstPasukFontColor = 'Red';
    params.secondPasukFontColor = 'Green';
    params.tajPasukFontColor = 'Blue';

    // DARK - RGB
    params.firstPasukFontColor = 'DarkRed';
    params.secondPasukFontColor = 'DarkGreen';
    params.tajPasukFontColor = 'DarkBlue';

    //params.divPasukPadding = '18px';

    // DARK - BGR
    //params.firstPasukFontColor = 'DarkBlue';
    //params.secondPasukFontColor = '#004400';//'#45008B';// 'DarkGreen';
    //params.tajPasukFontColor = 'DarkRed';

    //changeBaseHtml(params);

    function changeBaseHtml(params) {

        // Start -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

        //$('div.pasuk_mikra_1').css('padding', '4px');

        //$('div.pasuk2m1t').css('padding', params.divPasukPadding, '!important');

        //$('#accordionContainer').css('')

        $('h5.header').css('font-size', '12px', '!important');
        $('h5.header').css('padding-top', params.pasukPaddingTop, '!important');

        //$('.accordion.verse.header').css('height', '28px', '!important');

        $('div.pasuk_mikra_1').css('font-family', params.firstPasukFontFamily, '!important');
        $('div.pasuk_mikra_2').css('font-family', params.secondPasukFontFamily, '!important');
        $('div.pasuk_taj_1').css('font-family', params.tajPasukFontFamily, '!important');

        // Font Size
        $('div.pasuk_mikra_1').css('font-size', params.firstPasukFontSize + params.fontSizeTypeDesc, '!important');
        $('div.pasuk_mikra_2').css('font-size', params.secondPasukFontSize + params.fontSizeTypeDesc, '!important');
        $('div.pasuk_taj_1').css('font-size', params.tajPasukFontSize + params.fontSizeTypeDesc, '!important');

        // Font Weight
        $('div.pasuk_mikra_1').css('font-weight', params.firstPasukFontWeight, '!important');
        $('div.pasuk_mikra_2').css('font-weight', params.secondPasukFontWeight, '!important');
        $('div.pasuk_taj_1').css('font-weight', params.tajPasukFontWeight, '!important');

        // Text Color
        $('div.pasuk_mikra_1').css('color', params.firstPasukFontColor, '!important');
        $('div.pasuk_mikra_2').css('color', params.secondPasukFontColor, '!important');
        $('div.pasuk_taj_1').css('color', params.tajPasukFontColor, '!important');

        // Line height
        $('div.pasuk_mikra_1').css('line-height', params.firstPasukLineHeight + params.lineHeightTypeDesc);
        $('div.pasuk_mikra_2').css('line-height', params.secondPasukLineHeight + params.lineHeightTypeDesc);
        $('div.pasuk_taj_1').css('line-height', params.tajPasukLineHeight + params.lineHeightTypeDesc);

        $('div.pasuk_mikra_1').css('text-align', 'justify', '!important');
        $('div.pasuk_mikra_2').css('text-align', 'justify', '!important');
        $('div.pasuk_taj_1').css('text-align', 'justify', '!important');

        $('div.pasuk_mikra_1').css('transform', params.transformScaleY, '!important');
        $('div.pasuk_mikra_2').css('transform', params.transformScaleY, '!important');
        $('div.pasuk_taj_1').css('transform', params.transformScaleY, '!important');

        $('div.pasuk_mikra_1').css('margin-top', params.pasukMarginTop, '!important');
        $('div.pasuk_mikra_2').css('margin-top', params.pasukMarginTop, '!important');
        $('div.pasuk_taj_1').css('margin-top', params.pasukMarginTop, '!important');


        $('div.pasuk_mikra_1').css('margin-bottom', params.pasukMarginBottom, '!important');
        $('div.pasuk_mikra_2').css('margin-bottom', params.pasukMarginBottom, '!important');
        $('div.pasuk_taj_1').css('margin-bottom', params.pasukMarginBottom, '!important');

        //$('div.pasuk_mikra_1').css('padding', params.firstPasukPaddingTop + ' ' + params.firstPasukPadding, '!important');
        //$('div.pasuk_mikra_2').css('padding', params.firstPasukPaddingTop + ' ' + params.firstPasukPadding, '!important');
        //$('div.pasuk_taj_1').css('padding', params.firstPasukPaddingTop + ' ' + params.firstPasukPadding, '!important');


        // Change TAJ text: from יְיָ to: יְהֹוָה
        //$('div.pasuk_taj_1').each(function () {
        //    var currentTaj = $(this).text();
        //    currentTaj = currentTaj.replace(/יְיָ/g, 'יְהֹוָה');

        //    currentTaj = currentTaj.replace(/וַייָ/g, 'וַיְהֹוָה');

        //    currentTaj = currentTaj.replace(/דַּייָ/g, 'דַּיְהֹוָה');

        //    currentTaj = currentTaj.replace(/דַּייָ/g, 'דַּיְהֹוָה');

        //    //וַייָ
        //    //דַּייָ
        //    currentTaj = $.removeNonAscii(currentTaj);

        //    $(this).text(currentTaj);
        //});

        //$('div.pasuk_mikra_2').each(function () {
        //    var currentText = $(this).text();

        //    currentText = $.removeNonAscii(currentText);

        //    $(this).text(currentText);
        //});
    }
});
