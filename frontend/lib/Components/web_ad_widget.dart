// import 'dart:html' as html;
// import 'dart:ui_web' as ui_web; 
// import 'package:flutter/material.dart';

// // This file is ONLY used when running on the Web
// class WebAdWidget extends StatefulWidget {
//   final String adSlot;
//   final String adClient;

//   const WebAdWidget({
//     super.key,
//     required this.adSlot,
//     required this.adClient,
//   });

//   @override
//   State<WebAdWidget> createState() => _WebAdWidgetState();
// }

// class _WebAdWidgetState extends State<WebAdWidget> {
//   final String _viewID = 'ad-view-${UniqueKey().toString()}';

//   @override
//   void initState() {
//     super.initState();
    
//     // ignore: undefined_prefixed_name
//     ui_web.platformViewRegistry.registerViewFactory(
//       _viewID,
//       (int viewId) {
//         final html.Element adContainer = html.DivElement();
        
//         adContainer.style.width = '100%';
//         adContainer.style.height = '100%'; 
//         adContainer.style.display = 'flex';
//         adContainer.style.justifyContent = 'center';
//         adContainer.style.alignItems = 'center';

//         final html.Element ins = html.Element.tag('ins');
//         ins.className = 'adsbygoogle';
//         ins.style.display = 'block';
        
//         ins.style.minWidth = '10px'; 
//         ins.style.width = '100%';
//         ins.style.height = '100%';

//         ins.setAttribute('data-ad-client', widget.adClient);
//         ins.setAttribute('data-ad-slot', widget.adSlot);
//         ins.setAttribute('data-ad-format', 'auto');
//         ins.setAttribute('data-full-width-responsive', 'true');

//         adContainer.append(ins);

//         final html.ScriptElement script = html.ScriptElement();
//         script.innerHtml = '''
//           setTimeout(function() {
//             try {
//               (adsbygoogle = window.adsbygoogle || []).push({});
//             } catch (e) {
//               console.log("AdSense Error: ", e);
//             }
//           }, 500);
//         ''';
//         adContainer.append(script);

//         return adContainer;
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 50, 
//       width: double.infinity,
//       child: HtmlElementView(viewType: _viewID),
//     );
//   }
// }