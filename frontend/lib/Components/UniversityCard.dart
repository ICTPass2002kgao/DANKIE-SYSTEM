import 'package:flutter/material.dart'; 

class UniversityCard extends StatelessWidget {
  final String UniName;
  final String uniAddress;
  final String? imageUrl;
  final String applicationLink;
  final bool applicationIsOpen;
  final Function() onPressed;
  const UniversityCard({
    super.key,
    this.imageUrl,
    required this.UniName,
    required this.uniAddress,
    required this.applicationLink,
    required this.onPressed,
    required this.applicationIsOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: Border.all(color: color.primaryColor),
        borderRadius: BorderRadius.circular(19.5),
        color: color.scaffoldBackgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl == null || imageUrl!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: color.hintColor,
                  child: Icon(
                    Icons.location_city,
                    size: 70,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              )
            else
              Center(
                child: Container(
                  height: 100,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Image.network(imageUrl!, fit: BoxFit.scaleDown),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      UniName,

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Center(
                    child: Text(
                      applicationIsOpen == true
                          ? 'Application open'
                          : 'Application closed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: applicationIsOpen == true
                            ? color.splashColor
                            : color.primaryColorDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),

                  SizedBox(height: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
