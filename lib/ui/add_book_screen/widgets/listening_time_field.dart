import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DurationInputDialog {
  static Future<void> show(
      BuildContext context, 
      Function(int) onDurationSelected, 
      {int initialSeconds = 0}) async {
    
    final TextEditingController daysCtrl = TextEditingController();
    final TextEditingController hoursCtrl = TextEditingController();
    final TextEditingController minutesCtrl = TextEditingController();

    // Calculer les jours, heures et minutes à partir des secondes initiales
    int days = initialSeconds ~/ 86400;
    int hours = (initialSeconds % 86400) ~/ 3600;
    int minutes = (initialSeconds % 3600) ~/ 60;

    // Initialiser les contrôleurs avec les valeurs calculées
    daysCtrl.text = days.toString();
    hoursCtrl.text = hours.toString();
    minutesCtrl.text = minutes.toString();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Entrer la durée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: daysCtrl,
                decoration: InputDecoration(
                  labelText: 'Jours',
                  hintText: 'Entrez le nombre de jours',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: hoursCtrl,
                decoration: InputDecoration(
                  labelText: 'Heures',
                  hintText: 'Entrez le nombre d\'heures',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: minutesCtrl,
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  hintText: 'Entrez le nombre de minutes',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer le dialogue
              },
              child: Text('Annuler'),
            ),

            FilledButton(
              onPressed: () {
                // Calculer le total en secondes
                int totalSeconds = (int.tryParse(daysCtrl.text) ?? 0) * 86400 +
                                   (int.tryParse(hoursCtrl.text) ?? 0) * 3600 +
                                   (int.tryParse(minutesCtrl.text) ?? 0) * 60;
                
                // Renvoyer le résultat via le callback
                onDurationSelected(totalSeconds);
                Navigator.of(context).pop(); // Fermer le dialogue
              },
              child: Text('Valider'),
            ),
          ],
        );
      },
    );
  }
}
