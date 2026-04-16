/// Classifies FHIR resources into meaningful categories for DTL mapping
/// Especially important for Observation resources which map to different SDA3 classes
Class HS.Local.zimpli.fhir.Workbench.Classifier Extends %RegisteredObject
{

/// Classifies an Observation resource into a subtype based on category and LOINC codes
/// Returns: "vital-signs", "laboratory", "social-history", "imaging", "procedure", "survey", or "other"
ClassMethod ClassifyObservation(pObservation As %DynamicObject) As %String
{
    Set tCategory = ""
    Set tCode = ""
    Set tResult = ""

    // Check category
    If $IsObject(pObservation.category) {
        For i=0:1:pObservation.category.%Size()-1 {
            Set tCat = pObservation.category.%Get(i)
            Continue:'$IsObject(tCat)
            Continue:'$IsObject(tCat.coding)

            For j=0:1:tCat.coding.%Size()-1 {
                Set tCoding = tCat.coding.%Get(j)
                Continue:'$IsObject(tCoding)

                Set tCatCode = $ZCONVERT($Get(tCoding.code),"L")

                // Standard FHIR observation categories
                If tCatCode="vital-signs" {
                    Set tResult = "vital-signs"
                    Quit
                }
                If tCatCode="laboratory" {
                    Set tResult = "laboratory"
                    Quit
                }
                If tCatCode="social-history" {
                    Set tResult = "social-history"
                    Quit
                }
                If tCatCode="imaging" {
                    Set tResult = "imaging"
                    Quit
                }
                If tCatCode="procedure" {
                    Set tResult = "procedure"
                    Quit
                }
                If tCatCode="survey" {
                    Set tResult = "survey"
                    Quit
                }
            }
            Quit:tResult'=""
        }
    }

    // Return early if found
    If tResult'="" Return tResult

    // Fallback: Check LOINC codes for vitals
    If $IsObject(pObservation.code), $IsObject(pObservation.code.coding) {
        For i=0:1:pObservation.code.coding.%Size()-1 {
            Set tCoding = pObservation.code.coding.%Get(i)
            Continue:'$IsObject(tCoding)

            Set tSystem = $ZCONVERT($Get(tCoding.system),"L")
            Set tCode = $Get(tCoding.code)

            If tSystem["loinc" {
                // Common vital sign LOINCs
                If ..IsVitalSignLOINC(tCode) {
                    Return "vital-signs"
                }
            }
        }
    }

    Quit "other"
}

/// Checks if LOINC code is a common vital sign
ClassMethod IsVitalSignLOINC(pLOINC As %String) As %Boolean
{
    // Blood pressure
    If pLOINC="85354-9" Quit 1  // Blood pressure panel
    If pLOINC="8480-6" Quit 1   // Systolic BP
    If pLOINC="8462-4" Quit 1   // Diastolic BP
    If pLOINC="55284-4" Quit 1  // Blood pressure systolic and diastolic

    // Temperature
    If pLOINC="8310-5" Quit 1   // Body temperature
    If pLOINC="8331-1" Quit 1   // Oral temperature

    // Heart rate
    If pLOINC="8867-4" Quit 1   // Heart rate

    // Respiratory rate
    If pLOINC="9279-1" Quit 1   // Respiratory rate

    // SpO2
    If pLOINC="59408-5" Quit 1  // Oxygen saturation
    If pLOINC="2708-6" Quit 1   // Oxygen saturation

    // Weight/Height/BMI
    If pLOINC="29463-7" Quit 1  // Body weight
    If pLOINC="8302-2" Quit 1   // Body height
    If pLOINC="39156-5" Quit 1  // BMI

    Quit 0
}

/// Returns display name for resource subtype
ClassMethod GetSubTypeDisplayName(pResourceType As %String, pSubType As %String) As %String
{
    If pResourceType="Observation" {
        If pSubType="vital-signs" Quit "Vital Signs"
        If pSubType="laboratory" Quit "Laboratory Results"
        If pSubType="social-history" Quit "Social History"
        If pSubType="imaging" Quit "Imaging"
        If pSubType="procedure" Quit "Procedure"
        If pSubType="survey" Quit "Survey"
        If pSubType="other" Quit "Other Observations"
    }

    Quit pSubType
}

/// Maps resource type/subtype to likely SDA3 class
ClassMethod GetSDA3Class(pResourceType As %String, pSubType As %String = "") As %String
{
    If pResourceType="Patient" Quit "HS.SDA3.Patient"
    If pResourceType="Encounter" Quit "HS.SDA3.Encounter"
    If pResourceType="Condition" Quit "HS.SDA3.Diagnosis"
    If pResourceType="Procedure" Quit "HS.SDA3.Procedure"
    If pResourceType="MedicationStatement" Quit "HS.SDA3.Medication"
    If pResourceType="AllergyIntolerance" Quit "HS.SDA3.Allergy"
    If pResourceType="Immunization" Quit "HS.SDA3.Vaccination"

    If pResourceType="Observation" {
        If pSubType="vital-signs" Quit "HS.SDA3.Vital"
        If pSubType="laboratory" Quit "HS.SDA3.LabOrder"
        If pSubType="social-history" Quit "HS.SDA3.SocialHistory"
        Quit "HS.SDA3.Result"
    }

    Quit ""
}

}
