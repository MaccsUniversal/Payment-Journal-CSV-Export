
pageextension 99011 "Payment Journal MO" extends "Payment Journal"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addFirst("Electronic Payments")
        {

            action(ExportPaymentFile)
            {
                Caption = 'Export Payment CSV';
                Promoted = true;
                PromotedCategory = Category4;
                Image = ExportFile;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Xmlport.Run(99001, false, false);
                end;
            }
        }
    }

    var
        myInt: Integer;
}
xmlport 99001 "Payment Journal Export MOO"
{
    Format = VariableText;
    Direction = Export;
    TextEncoding = UTF8;
    UseRequestPage = false;
    TableSeparator = '<NewLine>';
    FieldDelimiter = '"';
    FieldSeparator = ',';
    FileName = 'Payment Export File.csv';



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
                textelement(Creditor) { }

                fieldelement(Amount; GenJournalLine.Amount)
                {
                    trigger OnBeforePassField()
                    begin
                        if GenJournalLine.Amount <= 0 then
                            Error('Payment amount must be greater that ''0.00''. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;

                }

                fieldelement(Name; GenJournalLine.Description) { }

                textelement(BankSortCode)
                {
                    trigger OnBeforePassVariable()
                    var
                        VendorBankAcc: Record "Vendor Bank Account";
                    begin
                        BankSortCode := GetBankDetails('BankSortCode');
                        if StrLen(BankSortCode) <> 6 then
                            Error('Bank Sort Code Should be 6 Digits Long For UK Suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;
                }

                textelement(BankAccountNo)
                {
                    trigger OnBeforePassVariable()
                    begin
                        BankAccountNo := GetBankDetails('BankAccountNo');
                        if StrLen(BankAccountNo) <> 8 then
                            Error('Bank Account No. Should be 8 Digits Long For UK Suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3,', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
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
    begin
        DateFormat := '<Year4><Month,2><Day,2>';
        Header := 'H';
        UploadDate := Format(Today(), 8, DateFormat);
        ValueDate := Format(GetPostingDate(), 8, DateFormat);
        PageNumber := '1';
        Creditor := 'C';
        CompanyName := 'Sovereign Partners';
        TerminateProcess := 'T';
    end;

    local procedure GetBankDetails(AccountDetail: Text): Text
    var
        VendorBankAcc: Record "Vendor Bank Account";
    begin
        VendorBankAcc.SetFilter("Vendor No.", GenJournalLine."Account No.");
        VendorBankAcc.SetCurrentKey("Vendor No.");
        if not VendorBankAcc.FindSet() then
            error('Cannot to find Vendor Account No. for General Journal Line=%1 General Journal Line Batch Name=%2', GenJournalLine."Line No.", GenJournalLine."Journal Batch Name");
        VendorBankAcc.TestField(Code, GenJournalLine."Account No.");
        case AccountDetail of
            'BankAccountNo':
                exit(Format(VendorBankAcc."Bank Account No."));
            'BankSortCode':
                exit(Format(VendorBankAcc."Bank Branch No."));
        end;
        VendorBankAcc.Reset();
    end;

    local procedure GetPostingDate(): Date
    var
        GenJnlLines: Record "Gen. Journal Line";
    begin
        GenJnlLines.FindFirst();
        exit(GenJnlLines."Posting Date");
    end;
}

