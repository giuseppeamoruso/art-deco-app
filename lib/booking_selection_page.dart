import 'package:flutter/material.dart';
import 'service_selection_page.dart';

class BookingSelectionPage extends StatelessWidget {
  const BookingSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Prenota Appuntamento',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header informativo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.content_cut,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Seleziona la sezione',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scegli la sezione per cui vuoi prenotare il tuo appuntamento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Sezioni Uomo e Donna
              Expanded(
                child: Column(
                  children: [
                    // Sezione Donna
                    _buildElegantSectionCard(
                      context: context,
                      imagePath: 'assets/images/donna.png',
                      mainText: 'DONNA',
                      subtitle: 'PRENOTA',
                      isWoman: true,
                      onTap: () {
                        // Naviga alla prenotazione per donna
                        _navigateToBooking(context, 'donna');
                      },
                    ),

                    const SizedBox(height: 20),

                    // Sezione Uomo
                    _buildElegantSectionCard(
                      context: context,
                      imagePath: 'assets/images/uomo.png',
                      mainText: 'UOMO',
                      subtitle: 'PRENOTA',
                      isWoman: false,
                      onTap: () {
                        // Naviga alla prenotazione per uomo
                        _navigateToBooking(context, 'uomo');
                      },
                    ),

                    const Spacer(),

                    // Info stylist
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2d2d2d),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '4 Stylist professionali a tua disposizione',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElegantSectionCard({
    required BuildContext context,
    required String imagePath,
    required String mainText,
    required String subtitle,
    required bool isWoman,
    required VoidCallback onTap,
  }) {
    return Card(
      color: isWoman ? Colors.white : const Color(0xFF2d2d2d),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 140,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isWoman
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
                Colors.white,
              ],
            )
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.6),
                const Color(0xFF2d2d2d),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Immagine al posto del testo script
              Flexible(
                child: Container(
                  height: 40, // Ridotto da 50 a 40
                  child: Image.asset(
                    imagePath,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback se l'immagine non si carica
                      return Text(
                        isWoman ? 'Woman' : 'Man',
                        style: const TextStyle(
                          fontFamily: 'Serif',
                          fontSize: 24, // Ridotto da 28 a 24
                          color: Color(0xFFFFD700), // Oro/Giallo
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.5,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 4), // Ridotto da 6 a 4

              // Testo principale (UOMO/DONNA) - bianco per uomo, nero per donna
              Flexible(
                child: Text(
                  mainText,
                  style: TextStyle(
                    color: isWoman ? Colors.black : Colors.white,
                    fontSize: 22, // Ridotto da 24 a 22
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5, // Ridotto da 3.0 a 2.5
                  ),
                ),
              ),

              const SizedBox(height: 4), // Ridotto da 6 a 4

              // Sottotitolo - grigio scuro per donna, grigio chiaro per uomo
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: isWoman ? Colors.grey[600] : Colors.grey[400],
                    fontSize: 12, // Ridotto da 14 a 12
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5, // Ridotto da 2.0 a 1.5
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToBooking(BuildContext context, String section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServiceSelectionPage(section: section),
      ),
    );
  }
}