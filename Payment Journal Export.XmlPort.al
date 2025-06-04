
pageextension 50110 "Payment Journal MO" extends "Payment Journal"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addlast("&Payments")
        {

            action(ExportPaymentFile)
            {
                Caption = 'Export Payment';
                Promoted = true;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Xmlport.Run(50100, false, false);
                end;
            }
        }
    }

    var
        myInt: Integer;
}
xmlport 50100 "Payment Journal Export MOO"
{
    Format = VariableText;
    Direction = Export;
    TextEncoding = UTF8;
    UseRequestPage = false;
    TableSeparator = '<NewLine>';
    FieldDelimiter = '"';
    FieldSeparator = ',';


    schema
    {
        textelement(Root)
        {
            XmlName = 'Root';

            tableelement(HeaderRow; Integer)
            {
                SourceTableView = sorting(number) where(number = const(1));
                XmlName = 'HeaderRow';

                textelement(Header) { }

                textelement(UploadDate) { }

                textelement(PageNumber) { }

            }
            tableelement(BankCard; "Bank Account")
            {
                SourceTableView = where("No." = filter('LLOYDS BANK'));
                XmlName = 'SenderBankDetails';
                textelement(BankLineLabel)
                {
                    trigger OnBeforePassVariable()
                    begin
                        if BankCard."No." = 'LLOYDS BANK' then
                            BankLineLabel := Format('D');
                    end;
                }

                textelement(ValueDate) { }

                textelement(Uploader)
                {
                    trigger OnBeforePassVariable()
                    begin
                        Uploader := Format('Suppliers');
                    end;
                }

                textelement(BankDetails)
                {

                    trigger OnBeforePassVariable()
                    var
                        AccountNo: Text;
                        SortCode: Text;
                    begin
                        AccountNo := Format(BankCard."Bank Account No.");
                        SortCode := Format(BankCard."Bank Branch No.");
                        BankDetails := Format(SortCode + '-' + AccountNo);
                    end;
                }

            }
            tableelement("GenJournalLine"; "Gen. Journal Line")
            {

                SourceTableView = where("Journal Batch Name" = filter('DEFAULT'), "Account No." = filter(<> ''));
                XmlName = 'Lines';
                textelement(Creditor)
                {
                }

                fieldelement(Amount; GenJournalLine.Amount) { }

                fieldelement(Name; GenJournalLine.Description) { }

                textelement(SortCode)
                {
                    trigger OnBeforePassVariable()
                    var
                        VendorBankAcc: Record "Vendor Bank Account";
                    begin
                        SortCode := GetBankDetails('SortCode');
                    end;
                }

                textelement(AccountNo)
                {
                    trigger OnBeforePassVariable()
                    begin
                        AccountNo := GetBankDetails('AccountNo');
                    end;
                }

                textelement(CompanyName) { }
            }
            tableelement(Terminate; Integer)
            {
                SourceTableView = sorting(Number) where(Number = Const(1));
                XmlName = 'TerminateLine';

                textelement(TerminateProcess) { }
            }

        }

    }

    trigger OnInitXmlPort()
    var
        DateFormat: Text;
        CompanyInfo: Record "Company Information";
    begin
        DateFormat := '<Year4><Month,2><Day,2>';
        Header := 'H';
        UploadDate := Format(Today(), 8, DateFormat);
        ValueDate := Format(Today(), 8, DateFormat);
        PageNumber := '1';
        Creditor := 'C';
        CompanyName := CompanyInfo.Name;
        TerminateProcess := 'T';
    end;

    local procedure GetBankDetails(AccountDetail: Text): Text
    var
        VendorBankAcc: Record "Vendor Bank Account";
    begin
        if VendorBankAcc.Get(GenJournalLine."Account No.", GenJournalLine."Account No.") then
            case AccountDetail of
                'AccountNo':
                    exit(Format(VendorBankAcc."Bank Account No."));
                'SortCode':
                    exit(Format(VendorBankAcc."Bank Branch No."));
            end
        else
            error('Cannot to find Vendor Account No. for General Journal Line %1 General Journal Line Batch Name=%2', GenJournalLine."Line No.", GenJournalLine."Journal Batch Name");
    end;
}

