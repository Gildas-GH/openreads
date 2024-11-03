import 'dart:convert' as convert;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:openreads/core/constants/enums/book_status.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/logic/cubit/default_book_status_cubit.dart';
import 'package:openreads/logic/cubit/edit_book_cubit.dart';
import 'package:openreads/model/book.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openreads/core/constants/enums/enums.dart';
import 'package:openreads/ui/add_book_screen/add_book_screen.dart';

class ImportUrlPage extends StatefulWidget {
  const ImportUrlPage({
    super.key,
    required this.status,
  });

  final BookStatus status;

  @override
  State<ImportUrlPage> createState() => ImportUrlPageState();
}

class ImportUrlPageState extends State<ImportUrlPage> {
  Future<String?> fetchData(String url, CookieJar? cj) async {
    // Créer un cookie jar pour stocker les cookies
    cj ??= CookieJar();

    // Créer un client HTTP
    var client = HttpClient();

    // URL vers URI
    var uri = Uri.parse(url);

    var request = await client.openUrl('GET', uri);
    request.followRedirects = false;

    var headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate, br, zstd',
      'DNT': "1",
      'Sec-GPC': "1",
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': "1",
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'Priority': 'u=0, i',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
    };

    // Ajouter chaque en-tête à la requête
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    request.cookies.addAll(await cj.loadForRequest(uri));

    var response = await request.close();
    await cj.saveFromResponse(uri, response.cookies);
    if (response.statusCode == 200) {
      // Lire la réponse en tant que chaîne
      String responseString =
          await response.transform(convert.utf8.decoder).join();
      return responseString;
    } else if (response.statusCode == 302) {
      // Si redirection, suivre l'URL de redirection

      var redirectUrl = response.headers['location'];

      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        return await fetchData(redirectUrl[0],
            cj); // Appeler récursivement pour suivre la redirection
      }
    }
    client.close();
    return null;
  }

  final TextEditingController _urlController = TextEditingController();

  Future<String?> fetchOlid(String? isbn) async {
    var client = HttpClient();

    final request = await client.openUrl('GET', Uri.parse('https://openlibrary.org/api/volumes/brief/isbn/$isbn.json'));
    var response = await request.close();

    if (response.statusCode == 200) {
      String responseString =
        await response.transform(convert.utf8.decoder).join();

      var data = convert.jsonDecode(responseString);

      if (data is List) {
        return null;
      }
      // Accéder au premier OLID
      if (data != null && data.isNotEmpty == true) {
        if (data.containsKey('records')) {
          final records = data['records'];
          final firstRecord = records.values.first; // Prendre le premier enregistrement
          final olid = firstRecord['olids'].first; // Prendre le premier OLID
          return olid;
        }
      }
      return null;
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Fonction pour trouver l'année à quatre chiffres
  int? findFourDigitYears(String? date) {
    if (date == null) {
      return null;
    }
    RegExp yearPattern = RegExp(r'\b\d{4}\b');

    var match = yearPattern.firstMatch(date);
    if (match != null) {
      return int.parse(match.group(0)!);
    }
    return null;
  }

  Future<dynamic> extract(String url) async {
    // Get webpage content
    var htmlData = await fetchData(url, null);

    // Convert Response to a Document.
    var document = parse(htmlData);

    // Get JSON Structured Data
    Map<String, dynamic>? data = _parseToJson(document);
    // print(data);

    if (data == null) {
      return;
    }

    // Get title
    String title = data["name"];

    String? datePublished = data["datePublished"];

    int? numberOfPages;

    if (data.containsKey("numberOfPages")) {
      numberOfPages = int.parse(data["numberOfPages"]);
    }

    String? isbn;

    if (data.containsKey("isbn")) {
      isbn = data["isbn"];
    }

    if (data.containsKey("gtin13")) {
      isbn = data["gtin13"];
    }

    if (data.containsKey("offers")) {
      if (data["offers"] is Map) {
        // euh
      } else if (data["offers"] is List) {
        if ((data["offers"] as List).isNotEmpty) {
          if (data["offers"][0].containsKey("gtin13")) {
            isbn = data["offers"][0]["gtin13"];
          }
        }
      }
    }

    String author = '';

    if (data.containsKey('author')) {
      if (data['author'] is List) {
        List authors = data["author"];

        author = authors.map((author) => author['name']).join(', ');
      } else if (data['author'].containsKey("name")) {
        author = data["author"]["name"];
      }
    }

    String? publisher;

    if (data.containsKey('Publisher')) {
      publisher = data["Publisher"];
    } else if (data.containsKey('publisher')) {
      if (data["publisher"] is String) {
        publisher = data["publisher"];
      } else if (data["publisher"].containsKey("name")) {
        publisher = data["publisher"]["name"];
      }
    }

    String description = data["description"];

    String? image;

    if (data['image'] is List) {
      image = data["image"][0];
    } else {
      image = data["image"];
    }

    final defaultBookFormat = context.read<DefaultBooksFormatCubit>().state;

    final book = Book(
      title: title,
      subtitle: '',
      author: author,
      status: widget.status,
      favourite: false,
      pages: numberOfPages,
      isbn: isbn,
      olid: await fetchOlid(isbn),
      description: description,
      publicationYear: findFourDigitYears(datePublished),
      bookFormat: defaultBookFormat,
      readings: [],
      tags: LocaleKeys.owned_book_tag.tr(),
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    context.read<EditBookCubit>().setBook(book);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBookScreen(
          coverUrl: image,
        ),
      ),
    );
  }

  dynamic _parseToJson(dom.Document? document) {
    final data = document
        ?.querySelector("script[type='application/ld+json']")
        ?.innerHtml;
    if (data == null) {
      print('no json');
      return null;
    }
    var d = convert.jsonDecode(data);
    return d;
  }

  Future<void> _search() async {
    final String url = _urlController.text;
    if (url.isNotEmpty) {
      extract(url);
    } else {
      // Afficher un message d'erreur ou une notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please paste a valid URL.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import book via URL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'Paste URL here',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _search,
              child: Text('Search'),
            ),
          ],
        ),
      ),
    );
  }
}
